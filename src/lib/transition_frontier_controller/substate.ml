open Mina_base
open Core_kernel
include Bit_catchup_state.Substate_types

(** View the common substate.
    
    Viewer [~f] is applied to the common substate
    and its result is returned by the function.
  *)
let view (type state_t)
    ~state_functions:(module F : State_functions with type state_t = state_t) ~f
    =
  Fn.compose (Option.map ~f:snd)
    (F.modify_substate ~f:{ modifier = (fun st -> (st, f.viewer st)) })

(** [collect_ancestors top_state] collects transitions from the top state (inclusive) down the ancestry chain 
  while:
  
    1. Condition [predicate] is held
    and
    2. Have same state level as [top_state]

    Returned list of states is in the parent-first order.
*)
let collect_ancestors (type state_t) ~predicate ~state_functions
    ~(transition_states : state_t transition_states) =
  let (Transition_states ((module Transition_states), transition_states)) =
    transition_states
  in
  let (module F : State_functions with type state_t = state_t) =
    state_functions
  in
  let open F in
  let full_predicate state =
    Option.value ~default:(`Take false, `Continue false)
    @@ view ~state_functions ~f:predicate state
  in
  let rec loop res state =
    let `Take to_take, `Continue to_continue = full_predicate state in
    let res' = if to_take then state :: res else res in
    Option.value ~default:res'
    @@ let%bind.Option () = Option.some_if to_continue () in
       let parent_hash = (transition_meta state).parent_state_hash in
       let%bind.Option parent_state =
         Transition_states.find transition_states parent_hash
       in
       (* Parent is of different state => it's of higher state => we don't need to go deeper *)
       let%map.Option () =
         Option.some_if (equal_state_levels parent_state state) ()
       in
       loop res' parent_state
  in
  loop []

(** Modify status of common substate to [Processed].
    
    Function returns [Result.Ok] with new modified common substate
    and old [children] of the substate when substate has [Processing (Done x)] status
    and [Result.Error] otherwise.
*)
let mark_processed_modifier old_st subst =
  let old_children = subst.children in
  let reshape = function
    | Result.Error _ as e ->
        (subst, e)
    | Result.Ok subst' ->
        (subst', Result.Ok (old_st, old_children))
  in
  let children =
    { old_children with
      waiting_for_parent = State_hash.Set.empty
    ; processing_or_failed =
        State_hash.Set.union old_children.processing_or_failed
          old_children.waiting_for_parent
    }
  in
  reshape
  @@
  match subst.status with
  | Waiting_for_parent _ ->
      Result.Error (sprintf "waiting for parent")
  | Failed e ->
      Result.Error (sprintf "failed due to %s" (Error.to_string_mach e))
  | Processing (Done a_res) ->
      Result.Ok { status = Processed a_res; children }
  | Processing Dependent ->
      Result.Error "not started"
  | Processing (In_progress _) ->
      Result.Error "still processing"
  | Processed _ ->
      Result.Error "already processed"

(** Function takes transition and returns true when one of conditions hold:

  - Transition's parent is not in the catchup state (which means it's in frontier)

  - Transition's parent has a higher state level  *)
let is_parent_higher (type state_t)
    ~state_functions:(module F : State_functions with type state_t = state_t)
    state parent_opt =
  Option.value_map parent_opt
    ~f:
      (* Parent is found and differs in state level, hence it's of higher state *)
      (Fn.compose not (F.equal_state_levels state))
    ~default:
      (* Parent is not found which means the parent is in frontier.
         There is an invariant is that only non-processed states may have parent neither
         in frontier nor in transition_state. *)
      true

(** Start processing a transition in [Waiting_for_parent] status.
    
   Function modifies the status of the transition.

   It doesn't update parent's children structure, this is responsibility of the caller. *)
let kickstart_waiting_for_parent (type state_t)
    ~state_functions:(module F : State_functions with type state_t = state_t)
    ~logger ~(transition_states : state_t transition_states) state_hash =
  let (Transition_states ((module Transition_states), states)) =
    transition_states
  in
  let ext_modifier old_st subst =
    match subst.status with
    | Waiting_for_parent mk_status ->
        let status = mk_status () in
        let err_opt = match status with Failed e -> Some e | _ -> None in
        ( { subst with status }
        , Some (name_of_status status, F.name old_st, err_opt) )
    | _ ->
        (subst, None)
  in
  let modified_opt =
    Transition_states.modify_substate states ~f:{ ext_modifier } state_hash
  in
  match modified_opt with
  | None ->
      [%log warn] "child $state_hash not found"
        ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ]
  | Some None ->
      [%log warn] "child $state_hash is not in waiting_for_parent state"
        ~metadata:[ ("state_hash", State_hash.to_yojson state_hash) ]
  | Some (Some (status_name, state_name, err_opt)) ->
      let metadata =
        ("state_hash", State_hash.to_yojson state_hash)
        :: Option.to_list
             (Option.map err_opt ~f:(fun e ->
                  ("error", Error_json.error_to_yojson e) ) )
      in
      [%log debug]
        "Updating status of $state_hash from waiting for parent to %s (state: \
         %s)"
        status_name state_name ~metadata

(** Update children of the parent upon transition acquiring the [Processed] status *)
let update_children_on_processed (type state_t)
    ~(transition_states : state_t transition_states) ~parent_hash
    ~state_functions:(module F : State_functions with type state_t = state_t)
    state_hash =
  let modifier { children; status } =
    ( { status
      ; children =
          { children with
            processed = State_hash.Set.add children.processed state_hash
          ; processing_or_failed =
              State_hash.Set.remove children.processing_or_failed state_hash
          }
      }
    , () )
  in
  let (Transition_states ((module Transition_states), states)) =
    transition_states
  in
  Transition_states.modify_substate_ states ~f:{ modifier } parent_hash

(** [mark_processed_single state_hash] marks a transition as Processed.

  It returns a pair of old transition state and old children or [None] if
  marking as [Processed] failed.
  Children structure of [state_hash]'s parent is updated.
  Updating children of transition [state_hash] is responsibility of the caller.

  Pre-condition: Transition [state_hash] is in [Processing (Done _)] status
  Post-condition: list returned respects parent-child relationship and parent always comes first *)
let mark_processed_single (type state_t) ~logger ~state_functions
    ~(transition_states : state_t transition_states) state_hash =
  let (module F : State_functions with type state_t = state_t) =
    state_functions
  in
  let (Transition_states ((module Transition_states), states)) =
    transition_states
  in
  let open Option.Let_syntax in
  let%bind res =
    Transition_states.modify_substate states
      ~f:{ ext_modifier = mark_processed_modifier }
      state_hash
  in
  Option.iter
    ~f:(fun err -> [%log warn] "mark_processed: error %s" err)
    (Result.error res) ;
  let%map old_state, old_children = Result.ok res in
  let meta = F.transition_meta old_state in
  let parent_hash = meta.parent_state_hash in
  update_children_on_processed ~transition_states ~state_functions ~parent_hash
    meta.state_hash ;
  (old_state, old_children)

(** [mark_processed processed] marks a list of state hashes as Processed.

  It returns a list of state hashes to be promoted to higher state.
   
  Pre-conditions:
   1. Order of [processed] respects parent-child relationship and parent always comes first
   2. Respective substates for states from [processed] are in [Processing (Done _)] status
   3. Parents of all transitions from [processed] are in transition states or in frontier

  Post-condition: list returned respects parent-child relationship and parent always comes first *)
let mark_processed (type state_t) ~logger ~state_functions
    ~(transition_states : state_t transition_states) =
  let (module F : State_functions with type state_t = state_t) =
    state_functions
  in
  let (Transition_states ((module Transition_states), states)) =
    transition_states
  in
  let kickstart_waiting =
    kickstart_waiting_for_parent ~state_functions ~logger ~transition_states
  in
  let promoted = ref State_hash.Set.empty in
  let rec traverse_processed hash =
    let viewer { children; status } =
      (* This check should be redundant after debugging TODO *)
      match status with
      | Processed _ ->
          children
      | _ ->
          failwith
            (sprintf "traverse_processed: child not processed %s"
               (State_hash.to_base58_check hash) )
    in
    let open Option in
    Transition_states.find states hash
    >>= view ~state_functions ~f:{ viewer }
    >>| traverse_processed_children
    |> value_map ~f:(List.cons hash) ~default:[ hash ]
  and traverse_processed_children children =
    promoted := State_hash.Set.union children.processed !promoted ;
    List.concat_map ~f:traverse_processed
      (State_hash.Set.to_list children.processed)
  in
  let handle hash =
    let%bind.Option old_state, old_children =
      mark_processed_single ~logger ~state_functions ~transition_states hash
    in
    let meta = F.transition_meta old_state in
    let parent_hash = meta.parent_state_hash in
    State_hash.Set.iter ~f:kickstart_waiting old_children.waiting_for_parent ;
    let parent_opt = Transition_states.find states parent_hash in
    let%map.Option () =
      Option.some_if
        ( State_hash.Set.mem !promoted parent_hash
        || is_parent_higher ~state_functions old_state parent_opt )
        ()
    in
    (* Parent is of higher state, hence it needs to be promoted.

       We recursively traverse all of the processed ancestors because they
       also deserve promotion once the state becomes promoted.

       Note that transitions from [processed] won't be considered from
       within [traverse_processed_children] because [processed] is sorted
       in parent-first order and when a state from [processed] is considered,
       its children from [processed] are not yet marked processed (and hence won't
       be traversed). Neither can they appear in deeper layers of recursion. *)
    promoted := State_hash.Set.add !promoted hash ;
    hash :: traverse_processed_children old_children
  in
  List.concat_map ~f:(Fn.compose (Option.value ~default:[]) handle)

(** Update children of transition's parent when the transition is promoted
    to the higher state.

    This function removes the transition from parent's [Substate.processed] children
    set and adds it either to [Substate.waiting_for_parent] or
    [Substate.processing_or_failed] children set depending on the new status.

    When a transition's previous state was [Transition_state.Waiting_to_be_added_to_frontier],
    transition is not added to any of the parent's children sets.
*)
let update_children_on_promotion (type state_t) ~state_functions
    ~(transition_states : state_t transition_states) ~parent_hash ~state_hash
    state_opt =
  let (module F : State_functions with type state_t = state_t) =
    state_functions
  in
  let (Transition_states ((module Transition_states), states)) =
    transition_states
  in
  let add_if condition set =
    if condition then State_hash.Set.add set state_hash else set
  in
  let is_waiting_for_parent, is_processing_or_failed =
    let viewer subst =
      match subst.status with
      | Waiting_for_parent _ ->
          (true, false)
      | Processing _ | Failed _ ->
          (false, true)
      | _ ->
          (false, false)
    in
    Option.bind state_opt ~f:(view ~state_functions ~f:{ viewer })
    |> Option.value ~default:(false, false)
  in
  let modifier { children; status } =
    ( { status
      ; children =
          { processed = State_hash.Set.remove children.processed state_hash
          ; waiting_for_parent =
              add_if is_waiting_for_parent children.waiting_for_parent
          ; processing_or_failed =
              add_if is_processing_or_failed children.processing_or_failed
          }
      }
    , () )
  in
  Transition_states.modify_substate_ states ~f:{ modifier } parent_hash

(** [is_processing_done] functions takes state and returns true iff
    the status of the state is [Substate.Processing (Substate.Done _)]. *)
let is_processing_done ~state_functions =
  Fn.compose (Option.value ~default:false)
  @@ view ~state_functions
       ~f:
         { viewer =
             (fun subst ->
               match subst.status with
               | Processing (Done _) ->
                   true
               | _ ->
                   false )
         }

let add_error_if_failed ~tag = function
  | Failed e ->
      List.cons (tag, Error_json.error_to_yojson e)
  | _ ->
      Fn.id

module For_tests = struct
  (** [collect_failed_ancestry top_state] collects transitions from the top state (inclusive)
  down the ancestry chain that are:
  
    1. In [Failed] substate
    and
    2. Have same state level as [top_state]

    Returned list of states is in the parent-first order.
*)
  let collect_failed_ancestry ~state_functions ~transition_states top_state =
    let viewer s =
      match s.status with
      | Failed _ ->
          (`Take true, `Continue true)
      | _ ->
          (`Take false, `Continue true)
    in
    collect_ancestors ~predicate:{ viewer } ~state_functions ~transition_states
      top_state

  (** [collect_dependent_ancestry top_state] collects transitions from the top state (inclusive) down the ancestry chain 
  while collected states are:
  
    1. In [Waiting_for_parent], [Failed] or [Processing Dependent] substate
    and
    2. Have same state level as [top_state]

    States with [Processed] status are skipped through.
    Returned list of states is in the parent-first order.
*)
  let collect_dependent_ancestry ~state_functions ~transition_states top_state =
    let viewer s =
      match s.status with
      | Processing (In_progress _) ->
          (`Take false, `Continue false)
      | Waiting_for_parent _ | Failed _ | Processing _ ->
          (`Take true, `Continue true)
      | Processed _ ->
          (`Take false, `Continue true)
    in
    collect_ancestors ~predicate:{ viewer } ~state_functions ~transition_states
      top_state
end
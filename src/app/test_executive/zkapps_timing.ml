open Core
open Async
open Integration_test_lib

module Make (Inputs : Intf.Test.Inputs_intf) = struct
  open Inputs
  open Engine
  open Dsl

  open Test_common.Make (Inputs)

  type network = Network.t

  type node = Network.Node.t

  type dsl = Dsl.t

  let config =
    let open Test_config in
    { default with
      requires_graphql = true
    ; block_producers =
        [ { balance = "8000000000"; timing = Untimed }
        ; { balance = "1000000000"; timing = Untimed }
        ; { balance = "1000000000"; timing = Untimed }
        ]
    ; num_archive_nodes = 1
    ; num_snark_workers = 0
    }

  let run network t =
    let open Malleable_error.Let_syntax in
    let logger = Logger.create () in
    let block_producer_nodes = Network.block_producers network in
    let%bind () =
      Malleable_error.List.iter block_producer_nodes
        ~f:(Fn.compose (wait_for t) Wait_condition.node_to_initialize)
    in
    let node = List.hd_exn block_producer_nodes in
    let constraint_constants =
      Genesis_constants.Constraint_constants.compiled
    in
    let%bind fee_payer_pk = Util.pub_key_of_node node in
    let%bind fee_payer_sk = Util.priv_key_of_node node in
    let (keypair : Signature_lib.Keypair.t) =
      { public_key = fee_payer_pk |> Signature_lib.Public_key.decompress_exn
      ; private_key = fee_payer_sk
      }
    in
    let%bind ( zkapp_command_create_account_with_timing
             , timing_account_id
             , timing_update
             , timed_account_keypair ) =
      let open Mina_base in
      let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
      let amount = Currency.Amount.of_mina_int_exn 10 in
      let nonce = Account.Nonce.of_int 0 in
      let memo =
        Signed_command_memo.create_from_string_exn
          "zkApp create account with timing"
      in
      let zkapp_keypair = Signature_lib.Keypair.create () in
      let (zkapp_command_spec : Transaction_snark.For_tests.Deploy_snapp_spec.t)
          =
        { sender = (keypair, nonce)
        ; fee
        ; fee_payer = None
        ; amount
        ; zkapp_account_keypairs = [ zkapp_keypair ]
        ; memo
        ; new_zkapp_account = true
        ; snapp_update =
            (let timing =
               Zkapp_basic.Set_or_keep.Set
                 ( { initial_minimum_balance = Currency.Balance.of_mina_int_exn 5
                   ; cliff_time = Mina_numbers.Global_slot.of_int 10000
                   ; cliff_amount = Currency.Amount.of_nanomina_int_exn 10_000
                   ; vesting_period = Mina_numbers.Global_slot.of_int 2
                   ; vesting_increment =
                       Currency.Amount.of_nanomina_int_exn 1_000
                   }
                   : Account_update.Update.Timing_info.value )
             in
             { Account_update.Update.dummy with timing } )
        ; preconditions = None
        ; authorization_kind = Signature
        }
      in
      let timing_account_id =
        Account_id.create
          (zkapp_keypair.public_key |> Signature_lib.Public_key.compress)
          Token_id.default
      in
      return
        ( Transaction_snark.For_tests.deploy_snapp ~constraint_constants
            zkapp_command_spec
        , timing_account_id
        , zkapp_command_spec.snapp_update
        , zkapp_keypair )
    in
    let%bind zkapp_command_create_second_account_with_timing =
      let open Mina_base in
      let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
      let amount = Currency.Amount.of_mina_int_exn 10 in
      let nonce = Account.Nonce.of_int 2 in
      let memo =
        Signed_command_memo.create_from_string_exn
          "zkApp, 2nd account with timing"
      in
      let zkapp_keypair = Signature_lib.Keypair.create () in
      let (zkapp_command_spec : Transaction_snark.For_tests.Deploy_snapp_spec.t)
          =
        { sender = (keypair, nonce)
        ; fee
        ; fee_payer = None
        ; amount
        ; zkapp_account_keypairs = [ zkapp_keypair ]
        ; memo
        ; new_zkapp_account = true
        ; snapp_update =
            (* some maximal values to see GraphQL accepts them *)
            (let timing =
               Zkapp_basic.Set_or_keep.Set
                 ( { initial_minimum_balance = Currency.Balance.of_mina_int_exn 8
                   ; cliff_time = Mina_numbers.Global_slot.max_value
                   ; cliff_amount = Currency.Amount.max_int
                   ; vesting_period = Mina_numbers.Global_slot.of_int 2
                   ; vesting_increment =
                       Currency.Amount.of_nanomina_int_exn 1_000
                   }
                   : Account_update.Update.Timing_info.value )
             in
             { Account_update.Update.dummy with timing } )
        ; preconditions = None
        ; authorization_kind = Signature
        }
      in
      return
      @@ Transaction_snark.For_tests.deploy_snapp ~constraint_constants
           zkapp_command_spec
    in
    let%bind zkapp_command_transfer_from_timed_account =
      let open Mina_base in
      let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
      let amount = Currency.Amount.of_nanomina_int_exn 1_500_000 in
      let nonce = Account.Nonce.zero in
      let memo =
        Signed_command_memo.create_from_string_exn
          "zkApp transfer, timed account"
      in
      let sender_keypair = timed_account_keypair in
      let receiver = keypair.public_key |> Signature_lib.Public_key.compress in
      let (zkapp_command_spec
            : Transaction_snark.For_tests.Multiple_transfers_spec.t ) =
        { sender = (sender_keypair, nonce)
        ; fee
        ; fee_payer = None
        ; receivers = [ (receiver, amount) ]
        ; amount
        ; zkapp_account_keypairs = []
        ; memo
        ; new_zkapp_account = false
        ; snapp_update = Account_update.Update.dummy
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; sequence_events = []
        ; preconditions = None
        }
      in
      return
      @@ Transaction_snark.For_tests.multiple_transfers zkapp_command_spec
    in
    let%bind zkapp_command_invalid_transfer_from_timed_account =
      let open Mina_base in
      let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
      let amount = Currency.Amount.of_mina_int_exn 7 in
      let nonce = Account.Nonce.of_int 2 in
      let memo =
        Signed_command_memo.create_from_string_exn
          "Invalid transfer, timed account"
      in
      let sender_keypair = timed_account_keypair in
      let receiver = keypair.public_key |> Signature_lib.Public_key.compress in
      let (zkapp_command_spec
            : Transaction_snark.For_tests.Multiple_transfers_spec.t ) =
        { sender = (sender_keypair, nonce)
        ; fee
        ; fee_payer = None
        ; receivers = [ (receiver, amount) ]
        ; amount
        ; zkapp_account_keypairs = []
        ; memo
        ; new_zkapp_account = false
        ; snapp_update = Account_update.Update.dummy
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; sequence_events = []
        ; preconditions = None
        }
      in
      return
      @@ Transaction_snark.For_tests.multiple_transfers zkapp_command_spec
    in
    let%bind.Deferred zkapp_command_update_timing =
      let open Mina_base in
      let fee = Currency.Fee.of_nanomina_int_exn 1_000_000 in
      let amount = Currency.Amount.zero in
      let nonce = Account.Nonce.of_int 4 in
      let memo =
        Signed_command_memo.create_from_string_exn
          "zkApp, invalid update timing"
      in
      let snapp_update : Account_update.Update.t =
        { Account_update.Update.dummy with
          timing =
            Zkapp_basic.Set_or_keep.Set
              { initial_minimum_balance = Currency.Balance.of_mina_int_exn 9
              ; cliff_time = Mina_numbers.Global_slot.of_int 4000
              ; cliff_amount = Currency.Amount.of_nanomina_int_exn 100_000
              ; vesting_period = Mina_numbers.Global_slot.of_int 8
              ; vesting_increment = Currency.Amount.of_nanomina_int_exn 2_000
              }
        }
      in
      let (zkapp_command_spec : Transaction_snark.For_tests.Update_states_spec.t)
          =
        { sender = (keypair, nonce)
        ; fee
        ; fee_payer = None
        ; receivers = []
        ; amount
        ; zkapp_account_keypairs = [ timed_account_keypair ]
        ; memo
        ; new_zkapp_account = false
        ; snapp_update
        ; current_auth = Permissions.Auth_required.Proof
        ; call_data = Snark_params.Tick.Field.zero
        ; events = []
        ; sequence_events = []
        ; preconditions = None
        }
      in
      Transaction_snark.For_tests.update_states ~constraint_constants
        zkapp_command_spec
    in
    let with_timeout =
      let soft_slots = 3 in
      let soft_timeout = Network_time_span.Slots soft_slots in
      let hard_timeout = Network_time_span.Slots (soft_slots * 2) in
      Wait_condition.with_timeouts ~soft_timeout ~hard_timeout
    in
    let wait_for_zkapp ~has_failures zkapp_command =
      let%map () =
        wait_for t @@ with_timeout
        @@ Wait_condition.zkapp_to_be_included_in_frontier ~has_failures
             ~zkapp_command
      in
      [%log info] "zkApp transaction included in transition frontier"
    in
    let%bind () =
      section "Send a zkApp to create a zkApp account with timing"
        (send_zkapp ~logger node zkapp_command_create_account_with_timing)
    in
    let%bind () =
      section
        "Wait for snapp to create account with timing to be included in \
         transition frontier"
        (wait_for_zkapp ~has_failures:false
           zkapp_command_create_account_with_timing )
    in
    let%bind () =
      section "Send zkApp to create a 2nd zkApp account with timing"
        (send_zkapp ~logger node zkapp_command_create_second_account_with_timing)
    in
    let%bind () =
      section
        "Wait for snapp to create second account with timing to be included in \
         transition frontier"
        (wait_for_zkapp ~has_failures:false
           zkapp_command_create_second_account_with_timing )
    in
    let%bind () =
      section "Verify zkApp timing in ledger"
        (let%bind ledger_update =
           get_account_update ~logger node timing_account_id
         in
         if compatible_updates ~ledger_update ~requested_update:timing_update
         then (
           [%log info]
             "Ledger timing and requested timing update are compatible" ;
           return () )
         else (
           [%log error]
             "Ledger update and requested update are incompatible, possibly \
              because of the timing"
             ~metadata:
               [ ( "ledger_update"
                 , Mina_base.Account_update.Update.to_yojson ledger_update )
               ; ( "requested_update"
                 , Mina_base.Account_update.Update.to_yojson timing_update )
               ] ;

           Malleable_error.hard_error
             (Error.of_string
                "Ledger update and requested update with timing are \
                 incompatible" ) ) )
    in
    let%bind { total_balance = before_balance; _ } =
      Network.Node.must_get_account_data ~logger node
        ~account_id:timing_account_id
    in
    (* let%bind before_balance =
         get_account_balance ~logger node timing_account_id
       in *)
    let%bind () =
      section "Send a zkApp with transfer from timed account that succeeds"
        (send_zkapp ~logger node zkapp_command_transfer_from_timed_account)
    in
    let%bind () =
      section "Waiting for zkApp with transfer from timed account that succeeds"
        (wait_for_zkapp ~has_failures:false
           zkapp_command_transfer_from_timed_account )
    in
    (* let%bind after_balance =
         get_account_balance ~logger node timing_account_id
       in *)
    let%bind { total_balance = after_balance; _ } =
      Network.Node.must_get_account_data ~logger node
        ~account_id:timing_account_id
    in
    let%bind () =
      section "Verifying balance change"
        ( match
            Currency.Amount.( - )
              (Currency.Balance.to_amount before_balance)
              (Currency.Balance.to_amount after_balance)
          with
        | None ->
            Malleable_error.hard_error
              (Error.of_string
                 "Unexpected underflow when taking balance difference" )
        | Some diff ->
            let sender_account_update =
              (List.hd_exn
                 zkapp_command_transfer_from_timed_account.account_updates )
                .elt
                .account_update
            in
            let amount_to_send =
              Currency.Amount.Signed.magnitude
                (Mina_base.Account_update.balance_change sender_account_update)
            in
            let fee =
              Currency.Amount.of_fee
                (Mina_base.Zkapp_command.fee
                   zkapp_command_transfer_from_timed_account )
            in
            let total_debited =
              Option.value_exn (Currency.Amount.( + ) amount_to_send fee)
            in
            if Currency.Amount.equal diff total_debited then (
              [%log info] "Debited expected amount from timed account" ;
              return () )
            else
              Malleable_error.hard_error
                (Error.createf
                   "Expect to debit %s Mina from timed account (amount sent = \
                    %s, fee = %s), actually debited: %s Mina"
                   (Currency.Amount.to_string total_debited)
                   (Currency.Amount.to_string amount_to_send)
                   (Currency.Amount.to_string fee)
                   (Currency.Amount.to_string diff) ) )
    in
    let%bind () =
      section
        "Send a zkApp with transfer from timed account that fails due to min \
         balance"
        (let sender_account_update =
           (List.hd_exn
              zkapp_command_invalid_transfer_from_timed_account.account_updates )
             .elt
             .account_update
         in
         let amount_to_send =
           Currency.Amount.Signed.magnitude
             (Mina_base.Account_update.balance_change sender_account_update)
         in
         let fee =
           Currency.Amount.of_fee
             (Mina_base.Zkapp_command.fee
                zkapp_command_invalid_transfer_from_timed_account )
         in
         let total_to_debit =
           Option.value_exn (Currency.Amount.( + ) amount_to_send fee)
         in
         (* we have enough in account, disregarding min balance *)
         let proposed_balance =
           match
             Currency.Amount.( - )
               (Currency.Balance.to_amount after_balance)
               total_to_debit
           with
           | Some bal ->
               bal
           | None ->
               failwith "Amount to debit more than timed account balance"
         in
         let%bind { locked_balance_opt = locked_balance; _ } =
           Network.Node.must_get_account_data ~logger node
             ~account_id:timing_account_id
         in
         (* let%bind locked_balance =
              get_account_balance_locked ~logger node timing_account_id
            in *)
         (* but proposed balance is less than min ("locked") balance *)
         assert (
           Currency.Amount.( < ) proposed_balance
             (Option.value_exn locked_balance |> Currency.Balance.to_amount) ) ;
         send_zkapp ~logger node
           zkapp_command_invalid_transfer_from_timed_account )
    in
    let%bind () =
      section
        "Waiting for zkApp with transfer from timed account that fails due to \
         min balance"
        (wait_for_zkapp ~has_failures:true
           zkapp_command_invalid_transfer_from_timed_account )
    in
    (* TODO: use transaction status to see that the transaction failed
       as things are, we examine the balance of the sender to see that no funds were transferred
    *)
    let%bind () =
      section "Invalid transfer from timed account did not transfer funds"
        (* let%bind after_invalid_balance =
             get_account_balance ~logger node timing_account_id
           in *)
        (let%bind { total_balance = after_invalid_balance; _ } =
           Network.Node.must_get_account_data ~logger node
             ~account_id:timing_account_id
         in
         let after_invalid_balance_as_amount =
           Currency.Balance.to_amount after_invalid_balance
         in
         let expected_after_invalid_balance_as_amount =
           Currency.Amount.( - )
             (Currency.Balance.to_amount after_balance)
             (Currency.Amount.of_fee
                (Mina_base.Zkapp_command.fee
                   zkapp_command_invalid_transfer_from_timed_account ) )
           |> Option.value_exn
         in
         (* the invalid transfer should result in a fee deduction only *)
         if
           Currency.Amount.equal after_invalid_balance_as_amount
             expected_after_invalid_balance_as_amount
         then return ()
         else
           Malleable_error.hard_error
             (Error.createf
                "The zkApp transaction should have failed because of the \
                 minimum balance constraint, got an actual balance of %s, \
                 expected a balance of %s"
                (Currency.Balance.to_string after_invalid_balance)
                (Currency.Amount.to_string
                   expected_after_invalid_balance_as_amount ) ) )
    in
    let%bind () =
      section "Send a zkApp with invalid timing update"
        (send_zkapp ~logger node zkapp_command_update_timing)
    in
    let%bind () =
      section "Wait for snapp with invalid timing update"
        (wait_for_zkapp ~has_failures:true zkapp_command_update_timing)
    in
    let%bind () =
      section "Verify timing has not changed"
        (let%bind ledger_update =
           get_account_update ~logger node timing_account_id
         in
         if
           compatible_item ledger_update.timing timing_update.timing
             ~equal:Mina_base.Account_update.Update.Timing_info.equal
         then (
           [%log info]
             "Ledger update contains original timing, updated timing was not \
              applied, as desired" ;
           return () )
         else (
           [%log error]
             "Ledger update contains new timing, which should not have been \
              applied" ;
           Malleable_error.hard_error
             (Error.of_string "Ledger update contains a timing update") ) )
    in
    section_hard "Running replayer"
      (let%bind logs =
         Network.Node.run_replayer ~logger
           (List.hd_exn @@ Network.archive_nodes network)
       in
       check_replayer_logs ~logger logs )
end
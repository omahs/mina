open Core_kernel

let output_file = Out_channel.create Sys.argv.(1)

let output_string str = Out_channel.output_string output_file str

let () =
  (* We turn off warning 4 (fragile pattern-matching) globally for the generated
     code *)
     output_string
     {ocaml|
 (* This file is generated by gen_scalars/gen_scalars_plus.exe. *)

 (* turn off fragile pattern-matching warning from sexp ppx *)
 [@@@warning "-4"]

 type curr_or_next = Curr | Next
 [@@deriving hash, eq, compare, sexp]

 module Gate_type = struct
   module T = struct
     type t = Kimchi_types.gate_type =
       | Zero
       | Generic
       | Poseidon
       | CompleteAdd
       | VarBaseMul
       | EndoMul
       | EndoMulScalar
       | Lookup
       | CairoClaim
       | CairoInstruction
       | CairoFlags
       | CairoTransition
       | RangeCheck0
       | RangeCheck1
       | ForeignFieldAdd
       | ForeignFieldMul
       | Xor16
       | Rot64
     [@@deriving hash, eq, compare, sexp]
   end

   include Core_kernel.Hashable.Make (T)
   include T
 end

 module Lookup_pattern = struct
   module T = struct
     type t = Kimchi_types.lookup_pattern =
       | Xor
       | Lookup
       | RangeCheck
       | ForeignFieldMul
     [@@deriving hash, eq, compare, sexp]
   end

   include Core_kernel.Hashable.Make (T)
   include T
 end

 module Column = struct
   open Core_kernel

   module T = struct
     type t =
       | Witness of int
       | Index of Gate_type.t
       | Coefficient of int
       | LookupTable
       | LookupSorted of int
       | LookupAggreg
       | LookupKindIndex of Lookup_pattern.t
       | LookupRuntimeSelector
       | LookupRuntimeTable
     [@@deriving hash, eq, compare, sexp]
   end

   include Hashable.Make (T)
   include T
 end

 open Gate_type
 open Column

 module Env = struct
   type 'a t =
     { add : 'a -> 'a -> 'a
     ; sub : 'a -> 'a -> 'a
     ; mul : 'a -> 'a -> 'a
     ; pow : 'a * int -> 'a
     ; square : 'a -> 'a
     ; zk_polynomial : 'a
     ; omega_to_minus_zk_rows : 'a
     ; zeta_to_n_minus_1 : 'a
     ; zeta_to_srs_length : 'a Lazy.t
     ; var : Column.t * curr_or_next -> 'a
     ; field : string -> 'a
     ; cell : 'a -> 'a
     ; alpha_pow : int -> 'a
     ; double : 'a -> 'a
     ; endo_coefficient : 'a
     ; mds : int * int -> 'a
     ; srs_length_log2 : int
     ; vanishes_on_zero_knowledge_and_previous_rows : 'a
     ; joint_combiner : 'a
     ; beta : 'a
     ; gamma : 'a
     ; unnormalized_lagrange_basis : bool * int -> 'a
     ; if_feature : Kimchi_types.feature_flag * (unit -> 'a) * (unit -> 'a) -> 'a
     }
 end

 module type S = sig
   val constant_term : 'a Env.t -> 'a

   val index_terms : 'a Env.t -> 'a Lazy.t Column.Table.t
 end

(* The constraints are basically the same, but the literals in them differ. *)
module Tick : S = struct
  let constant_term (type a)
      ({ add = ( + )
       ; sub = ( - )
       ; mul = ( * )
       ; square
       ; mds
       ; endo_coefficient
       ; pow
       ; var
       ; field
       ; cell
       ; alpha_pow
       ; double
       ; zk_polynomial = _
       ; omega_to_minus_zk_rows = _
       ; zeta_to_n_minus_1 = _
       ; zeta_to_srs_length = _
       ; srs_length_log2 = _
       ; vanishes_on_zero_knowledge_and_previous_rows
       ; joint_combiner
       ; beta
       ; gamma
       ; unnormalized_lagrange_basis
       ; if_feature
       } :
        a Env.t) =
|ocaml}

external fp_linearization_plus : bool -> string * (string * string) array
  = "fp_linearization_strings_plus"

let fp_constant_term, fp_index_terms = fp_linearization_plus true

let () = output_string fp_constant_term

let () =
  output_string
    {ocaml|

  let index_terms (type a) (_ : a Env.t) =
    Column.Table.of_alist_exn
    [
|ocaml}

let is_first = ref true

let () =
  Array.iter fp_index_terms ~f:(fun (col, expr) ->
      if !is_first then is_first := false else output_string " ;\n" ;
      output_string "(" ;
      output_string col ;
      output_string ", lazy (" ;
      output_string expr ;
      output_string "))" )

let () = output_string {ocaml|
      ]
end
|ocaml}

(* TODO: two output strings (one goes into scalars_plus.ml), one for each gate definition *)
let () =
  output_string
    {ocaml|
module Tock : S = struct
  let constant_term (type a)
      ({ add = ( + )
       ; sub = ( - )
       ; mul = ( * )
       ; square
       ; mds
       ; endo_coefficient
       ; pow
       ; var
       ; field
       ; cell
       ; alpha_pow
       ; double
       ; zk_polynomial = _
       ; omega_to_minus_zk_rows = _
       ; zeta_to_n_minus_1 = _
       ; zeta_to_srs_length = _
       ; srs_length_log2 = _
       ; vanishes_on_zero_knowledge_and_previous_rows = _
       ; joint_combiner = _
       ; beta = _
       ; gamma = _
       ; unnormalized_lagrange_basis = _
       ; if_feature = _
       } :
        a Env.t) =
|ocaml}

external fq_linearization_plus : bool -> string * (string * string) array
  = "fq_linearization_strings_plus"

let fq_constant_term, fq_index_terms = fq_linearization_plus true

let () = output_string fq_constant_term

let () =
  output_string
    {ocaml|

  let index_terms (type a) (_ : a Env.t) =
    Column.Table.of_alist_exn
    [
|ocaml}

let is_first = ref true

let () =
  Array.iter fq_index_terms ~f:(fun (col, expr) ->
      if !is_first then is_first := false else output_string " ;\n" ;
      output_string "(" ;
      output_string col ;
      output_string ", lazy (" ;
      output_string expr ;
      output_string "))" )

let () = output_string {ocaml|
      ]
end
|ocaml}
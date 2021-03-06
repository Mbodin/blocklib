
open Libutils

type css_class = string

type link =
  | Simple
  | Button of bool

type layout =
  | Normal
  | Centered
  | Inlined
  | Navigation

type cell_option = {
    row : int ;
    col : int ;
    classes : css_class list
  }

let default = {
    row = 1 ;
    col = 1 ;
    classes = []
  }

type 'node block =
  | Div of layout * css_class list * 'node block list
  | P of 'node block list
  | Sequence of 'node block list
  | List of bool * 'node block list
  | Space
  | Text of string
  | Span of css_class list * string
  | FoldableBlock of bool * string * 'node block
  | LinkExtern of link * string * string
  | LinkContinuation of bool * link * string * (unit -> unit)
  | LinkFile of link * string * string * string * bool * (unit -> string)
  | Table of string list
             * ('node block * cell_option) list
             * (string list * ('node block * cell_option) list) list
  | Node of 'node

let rec add_spaces =
  let need_space = function
    | Div _ -> false
    | P _ -> false
    | Sequence _ -> true
    | List _ -> false
    | Space -> false
    | Text _ -> true
    | Span _ -> true
    | FoldableBlock _ -> true
    | LinkExtern _ -> true
    | LinkContinuation _ -> true
    | LinkFile _ -> true
    | Table _ -> false
    | Node _ -> false in
  let rec aux = function
    | [] -> []
    | a :: [] -> a :: []
    | a :: b :: l ->
      if need_space a && need_space b then
        a :: Text " " :: aux (b :: l)
      else a :: aux (b :: l) in
  let aux l = aux (List.map add_spaces l) in function
    | Div (layout, classes, l) -> Div (layout, classes, aux l)
    | P l -> P (aux l)
    | Sequence l -> Sequence (aux l)
    | List (visible, l) -> List (visible, List.map add_spaces l)
    | FoldableBlock (show, title, b) ->
      FoldableBlock (show, title, add_spaces b)
    | Table (classes, h, l) ->
      Table (classes, List.map (fun (b, o) -> (add_spaces b, o)) h,
             List.map (fun (classes, l) ->
               (classes, List.map (fun (b, o) -> (add_spaces b, o)) l)) l)
    | e -> e

type node_kind =
  | NormalResponse
  | ErrorResponse
  | RawResponse

module type T = sig

  val pause : unit -> unit Lwt.t
  val stopLoading : unit -> unit Lwt.t
  val startLoading : unit -> unit Lwt.t
  val setLoading : float -> unit Lwt.t

  val set_printing_mode : unit -> unit
  val unset_printing_mode : unit -> unit

  val log : string -> unit

  val get_file : string -> string Lwt.t

  val get_parameters : unit -> (string * string) list
  val set_parameters : (string * string) list -> unit

  val languages : string list

  type node

  type ('a, 'b) interaction = {
      node : node ;
      get : unit -> 'b ;
      set : 'a -> unit ;
      onChange : ('a -> unit) -> unit ;
      lock : unit -> unit ;
      unlock : unit -> unit ;
      locked : unit -> bool ;
      onLockChange : (bool -> unit) -> unit
    }
  type 'a sinteraction = ('a, 'a) interaction

  val synchronise : 'a sinteraction -> 'a sinteraction -> unit

  val block_node : node block -> node
  val print_node : ?kind:node_kind -> node -> unit
  val print_block : ?kind:node_kind -> node block -> unit
  val clear_response : unit -> unit

  val createIntegerOutput : int -> node * (int -> unit)
  val createFloatOutput : float -> node * (float -> unit)
  val createTextOutput : string -> node * (string -> unit)

  val createIntegerInput : ?min:int -> ?max:int -> int -> int sinteraction
  val createControlableIntegerInput : int -> int sinteraction * (int -> unit) * (int -> unit)
  val createFloatInput : ?min:float -> ?max:float -> float -> float sinteraction
  val createControlableFloatInput : float -> float sinteraction * (float -> unit) * (float -> unit)
  val createTextInput : string -> string sinteraction
  val createListInput : (string * 'a) list -> (string, (string * 'a) option) interaction
  val synchroniseListInput : (string, (string * 'a) option) interaction -> (string, (string * 'a) option) interaction -> unit
  val createResponsiveListInput : (string * 'a) list -> string -> (string -> (string * 'a) list) -> (string * 'a) list sinteraction
  val createControlableListInput : ('id * string option * 'a) list -> ('id option, 'a option) interaction * ('id -> string option -> unit)
  val createPercentageInput : float -> float sinteraction
  val createDateInput : Date.t -> Date.t sinteraction
  val createSwitch : string -> string option -> string option -> string option -> bool -> bool sinteraction
  val createFileImport : string list -> (unit -> unit Lwt.t) -> node * (unit -> (string * string) option Lwt.t)
  val clickableNode : node -> unit sinteraction
  val controlableNode : node -> node * (node -> unit)
  val removableNode : node -> node * (unit -> unit)
  val extendableNode : node -> node * (node -> unit)
  val extendableList : unit -> node * (node -> unit -> unit)

  val addClass : css_class list -> node -> node

end


(** Module InOut
   Specifies an interface for inputs and outputs. *)

open Libutils

(** A type for CSS-classes. *)
type css_class = string

(** The different kinds of link styles *)
type link =
  | Simple (** A usual text-based link. *)
  | Button of bool
    (** A link stylised as a button.
       The boolean states whether it is the main button or a secondary one. *)

(** The different kinds of div elements. *)
type layout =
  | Normal (** No special layout. *)
  | Centered (** Its content is centered. *)
  | Inlined (** The block is inlined. *)
  | Navigation (** A block for navigation items. *)

(** Specific options for cells in tables. *)
type cell_option = {
    row : int
      (** This integer enables rows to be merged: for each cells, it indicates
         how many rows are merged with the current cell.  If the integer is [1],
         the cell is a normal cell, but if it is more than [1], the cell has
         been merged with cells below. *) ;
    col : int (** Similar than [row], but merging columns instead of rows. *) ;
    classes : css_class list (** Some CSS-specific classes. *)
  }

(** The options for a normal cell. *)
val default : cell_option

(** A simplified representation of DOM’s nodes. *)
type 'node block =
  | Div of layout * css_class list * 'node block list (** A div node, with its layout. *)
  | P of 'node block list (** A paragraph node. *)
  | Sequence of 'node block list (** A sequence of blocks, displayed inlined. *)
  | List of bool * 'node block list
      (** A list of items.
         The boolean indicates whether bullets should be drawn. *)
  | Space (** Some space between texts. *)
  | Text of string (** A simple text. *)
  | Span of css_class list * string (** A text with some additional classes. *)
  | FoldableBlock of bool * string * 'node block
      (** A title that can hide a node.
         The boolean states whether the block should be unfolded by default. *)
  | LinkExtern of link * string * string
    (** A style, the link text, and its associated address. *)
  | LinkContinuation of bool * link * string * (unit -> unit)
      (** A link and its associated continuation.
         The boolean indicates whether the arrow is forwards. *)
  | LinkFile of link * string * string * string * bool * (unit -> string)
      (** Creates a link to a file whose content is computed.
         The first string argument is the link text, the second the file name,
         the third the mime type, and the fourth its content.
         The boolean indicates whether newlines should be adapted to the
         host’s operating system or not. *)
  | Table of string list
             * ('node block * cell_option) list
             * (string list * ('node block * cell_option) list) list
    (** A table, with its headers and its content (given line by line).
       It is also provided with some specific cell options for each content cell.
       Each line is also provided with a list of CSS classes, given as string.
       Finally, the whole table is associated with another list of CSS classes. *)
  | Node of 'node (** For all cases where more control is needed,
                     we can directly send a node. *)

(** Adds the expected spaces between block elements. *)
val add_spaces : 'node block -> 'node block

(** Describe how nodes are printed. *)
type node_kind =
  | NormalResponse (** A normal response from the program. *)
  | ErrorResponse (** An error message. *)
  | RawResponse (** A low-level response, printed as-is. *)

(** This is the signature specified in this file.
   It is satisfied by the various files [lib/inOut_*.ml]. *)
module type T = sig

  (** Pause the program for a short amount of time. *)
  val pause : unit -> unit Lwt.t

  (** Stop the loading animation. *)
  val stopLoading : unit -> unit Lwt.t

  (** Start the loading animation. *)
  val startLoading : unit -> unit Lwt.t

  (** Given a float between [0.] and [1.], set the corresponding loading in the loading animation.
     This function does not change the state of the animation: if the animation is stopped, it
     will not start it. *)
  val setLoading : float -> unit Lwt.t

  (** Set or unset the printing mode, a mode more adapted to printing. *)
  val set_printing_mode : unit -> unit
  val unset_printing_mode : unit -> unit

  (** Log the given message. *)
  val log : string -> unit

  (** Fetch a file from an address and returns its content. *)
  val get_file : string -> string Lwt.t

  (** Get parameters from the current address, in the form of a list of string. *)
  val get_parameters : unit -> (string * string) list

  (** Write parameters to the address. *)
  val set_parameters : (string * string) list -> unit

  (** The local set of accepted languages. *)
  val languages : string list


  (** An abstract type for representing nodes. *)
  type node

  (** A type for node interaction. *)
  type ('a, 'b) interaction = {
      node : node (** The node itself *) ;
      get : unit -> 'b (** Getting its value *) ;
      set : 'a -> unit (** Setting its value *) ;
      onChange : ('a -> unit) -> unit (** Calling a callback each time the value is changed *) ;
      lock : unit -> unit (** Lock the node: no one can change its value *) ;
      unlock : unit -> unit (** Unlock the node *) ;
      locked : unit -> bool (** Current lock status *) ;
      onLockChange : (bool -> unit) -> unit
        (** Calling a callback each time the node is locked or unlocked. *)
    }

  (** The type of safe interactions. *)
  type 'a sinteraction = ('a, 'a) interaction

  (** Making two safe interactions of the same time be copies of one another. *)
  val synchronise : 'a sinteraction -> 'a sinteraction -> unit

  (** Converts the block to a node. *)
  val block_node : node block -> node

  (** Adds the node to the [response] div in the main webpage. *)
  val print_node : ?kind:node_kind -> node -> unit

  (** A composition of [add_spaces], [block_node], and [print_node]. *)
  val print_block : ?kind:node_kind -> node block -> unit

  (** Clears the [response] div in the main webpage. *)
  val clear_response : unit -> unit


  (** Create a text output as a number which can be later reset. *)
  val createIntegerOutput : int -> node * (int -> unit)

  (** Create a text output as a floating-point number which can be later reset. *)
  val createFloatOutput : float -> node * (float -> unit)

  (** Create a text output as a string which can be later reset. *)
  val createTextOutput : string -> node * (string -> unit)


  (** Create a number input with default value given as argument. *)
  val createIntegerInput : ?min:int -> ?max:int -> int -> int sinteraction

  (** Similar to [createIntegerInput], but the [min] and [max] values can be changed after
     the node creation with the two returned functions. *)
  val createControlableIntegerInput : int -> int sinteraction * (int -> unit) * (int -> unit)

  (** Create a floating-point number input with default value given as argument. *)
  val createFloatInput : ?min:float -> ?max:float -> float -> float sinteraction

  (** Similar to [createFloatInput], but the [min] and [max] values can be changed after
     the node creation with the two returned functions. *)
  val createControlableFloatInput : float -> float sinteraction * (float -> unit) * (float -> unit)

  (** Create a text input with default value given as argument. *)
  val createTextInput : string -> string sinteraction

  (** Create a drop-down list where the user can choose one of its items.
     The lists are pairs of two elements: the displayed name of the element, and an element value. *)
  val createListInput : (string * 'a) list -> (string, (string * 'a) option) interaction

  (** Synchronise two drop-down lists.
     The function [synchronise] couldn’t be use in such a case because of the type of list inputs
     (they are not safe interactions). *)
  val synchroniseListInput : (string, (string * 'a) option) interaction -> (string, (string * 'a) option) interaction -> unit

  (** Create a text input meant to return a list of things.
     Each time that the user type a string, it is fed to its argument function.
     The strings of the returned list is shown to the user.  If the user chooses
     one of these elements, it is added to a list displayed next to the input.
     This final list can be fetched with the function returned with the node.
     The initial list and a placeholder string is given to the function to help
     the user. *)
  val createResponsiveListInput : (string * 'a) list -> string -> (string -> (string * 'a) list) -> (string * 'a) list sinteraction

  (** Create a drop-down list similar to [createListInput], but whose text content can be controled.
     This function returns a function able to change the display value of an item, given its
     identifier.
     If given [None], then the element will be hidden from the displayed list. *)
  val createControlableListInput : ('id * string option * 'a) list -> ('id option, 'a option) interaction * ('id -> string option -> unit)

  (** Create a range input between [0.] and [1.]. *)
  val createPercentageInput : float -> float sinteraction

  (** Create a date input. *)
  val createDateInput : Date.t -> Date.t sinteraction

  (** Create a switch button.
     The first string is the text associated with the button, to which can be
     added three facultative texts: one serving as a description, one added
     afterwards for when the button is on, and one when the button is off. *)
  val createSwitch : string -> string option -> string option -> string option -> bool -> bool sinteraction

  (** Create a button to import a file.
     It takes as argument the list of extension it accepts.
     It also takes as argument a function called before loading the file into
     memory.
     As of the other reading functions, it returns the created element and
     a reading function.
     This reading function returns both the file name and its content as two
     separate strings.
     It also might return [None] if no file has been selected. *)
  val createFileImport : string list -> (unit -> unit Lwt.t) -> node * (unit -> (string * string) option Lwt.t)

  (** Create a node which can be clicked.
     Clicks launch the [onChange] functions. *)
  val clickableNode : node -> unit sinteraction

  (** Create a new node whose content can be controlled by the returned function. *)
  val controlableNode : node -> node * (node -> unit)

  (** Create a node that can be removed by calling the returned function. *)
  val removableNode : node -> node * (unit -> unit)

  (** Create a node that can be extended by calling the returned function: the given node
     will be added at the end of the current one. *)
  val extendableNode : node -> node * (node -> unit)

  (** Create an empty list, which can be extended by new elements by calling the returned function.
     This function in turn returns a function to remove each added item. *)
  val extendableList : unit -> node * (node -> unit -> unit)

  (** Apply CSS classes to a node. *)
  val addClass : css_class list -> node -> node

end


open Js_of_ocaml


let pause _ = Lwt_js.sleep 0.01

(** Whether the loading animation is currently running. **)
let loading = ref true

let stopLoading _ =
  if !loading then (
    ignore (Js.Unsafe.fun_call (Js.Unsafe.js_expr "stopLoading") [||]) ;
    loading := false) ;
  Lwt_js.yield ()

let startLoading _ =
  if not !loading then (
    ignore (Js.Unsafe.fun_call (Js.Unsafe.js_expr "startLoading") [||]) ;
    loading := true ;
    pause ())
  else Lwt_js.yield ()


let get_file url =
  let (res, w) = Lwt.task () in
  let request = XmlHttpRequest.create () in
  request##_open (Js.string "GET") (Js.string url) Js._true ;
  request##overrideMimeType (Js.string "text/plain") ;
  request##.onreadystatechange :=
    Js.wrap_callback (fun _ ->
      if request##.readyState = XmlHttpRequest.DONE then (
        if request##.status = 200 then
          Lwt.wakeup_later w (Js.to_string request##.responseText)
        else
          Lwt.wakeup_later_exn w (Invalid_argument
               ("Error when fetching " ^ url ^ ". "
                ^ string_of_int request##.status ^ " :"
                ^ Js.to_string request##.statusText)))) ;
  request##send Js.null ;
  res


type layout =
  | Normal
  | Centered
  | Inlined

type block =
  | Div of layout * block list
  | P of block list
  | List of bool * block list
  | Space
  | Text of string
  | Link of string * string
  | LinkContinuation of bool * string * (unit -> unit)
  | LinkFile of string * string * string * string
  | Table of block list * block list list
  | Node of Dom_html.element Js.t

let rec add_spaces =
  let need_space = function
    | Div _ -> false
    | P _ -> false
    | List _ -> false
    | Space -> false
    | Text _ -> true
    | Link _ -> true
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
    | Div (layout, l) -> Div (layout, aux l)
    | P l -> P (aux l)
    | List (visible, l) ->
      (** Calling directly [add_spaces] instead of [aux]
       * to avoid adding elements to the list. **)
      List (visible, List.map add_spaces l)
    | Table (h, l) ->
      Table (List.map add_spaces h, List.map (List.map add_spaces) l)
    | e -> e

let document = Dom_html.window##.document

let rec block_node =
  let appendChilds f e =
    List.iter (fun b -> ignore (Dom.appendChild e (f (block_node b)))) in
  function
  | Div (layout, l) ->
    let div = Dom_html.createDiv document in
    let _ =
      match layout with
      | Normal -> ()
      | Centered ->
        div##.className := Js.string "center"
      | Inlined ->
        div##.className := Js.string "inlined" in
    appendChilds Utils.id div l ;
    (div :> Dom_html.element Js.t)
  | P l ->
    let p = Dom_html.createP document in
    appendChilds Utils.id p l ;
    (p :> Dom_html.element Js.t)
  | List (visible, l) ->
    let ul = Dom_html.createUl document in
    ul##.className := Js.string (if visible then "bullet" else "bulletless") ;
    appendChilds (fun n ->
      let li = Dom_html.createLi document in
      ignore (Dom.appendChild li n) ;
      li) ul l ;
    (ul :> Dom_html.element Js.t)
  | Space ->
    let span = Dom_html.createSpan document in
    ignore (span##setAttribute (Js.string "class") (Js.string "space")) ;
    (span :> Dom_html.element Js.t)
  | Text text ->
    let span = Dom_html.createSpan document in
    Dom.appendChild span (Dom_html.document##createTextNode (Js.string text)) ;
    (span :> Dom_html.element Js.t)
  | Link (text, link) ->
    let a = Dom_html.createA document in
    let text = Dom_html.document##createTextNode (Js.string text) in
    ignore (Dom.appendChild a text) ;
    a##.href := Js.string link ;
    (a :> Dom_html.element Js.t)
  | LinkContinuation (forwards, text, cont) ->
    let a = block_node (Link (text, "javascript:void(42)")) in
    if not forwards then
      ignore (a##setAttribute (Js.string "class") (Js.string "previous")) ;
    Lwt.async (fun _ ->
      Lwt_js_events.clicks a (fun _ _ -> Lwt.return (cont ()))) ;
    a
  | LinkFile (text, fileName, mime, cont) ->
      (* FIXME: Should I use
       * [File.blob_from_string ?contentType=mime ?ending=`native cont]? *)
    let content = Js.to_string (Js.encodeURIComponent (Js.string cont)) in
    let a =
      block_node (Link (text, "data:" ^ mime ^ ";charset=utf-8," ^ content)) in
    ignore (a##setAttribute (Js.string "download") (Js.string fileName)) ;
    a
  | Table (headers, content) ->
    let table = Dom_html.createTable document in
    let header = Dom_html.createTr document in
    ignore (Dom.appendChild table header) ;
    appendChilds (fun n ->
      let th = Dom_html.createTh document in
      ignore (Dom.appendChild th n) ;
      th) header headers ;
    List.iter (fun l ->
      let line = Dom_html.createTr document in
      ignore (Dom.appendChild table line) ;
      appendChilds (fun n ->
        let td = Dom_html.createTd document in
        ignore (Dom.appendChild td n) ;
        td) line l) content ;
    (table :> Dom_html.element Js.t)
  | Node n -> n

(** Returns the [response] div from the main webpage. **)
let get_response _ =
  Js.Opt.get (Dom_html.document##getElementById (Js.string "response")) (fun _ ->
    failwith "The element [response] has not been found in the webpage.")

let clear_response _ =
  let response = get_response () in
  let rec aux _ =
    match Js.Opt.to_option (response##.firstChild) with
    | Some n -> ignore (response##removeChild n) ; aux ()
    | None -> () in
  aux ()

let print_node n =
  let response = get_response () in
  let div = Dom_html.createDiv document in
  div##.className := Js.string "block" ;
  ignore (Dom.appendChild div n) ;
  ignore (Dom.appendChild response div)

let print_block =
  Utils.compose print_node (Utils.compose block_node add_spaces)


let createNumberInput d =
  let d = max 0 d in
  let input = Dom_html.createInput ~_type:(Js.string "number") document in
  ignore (input##setAttribute (Js.string "min") (Js.string "0")) ;
  ignore (input##setAttribute (Js.string "max")
           (Js.string (string_of_int max_int))) ;
  input##.value := Js.string (string_of_int d) ;
  ((input :> Dom_html.element Js.t), fun _ ->
    max 0 (int_of_string (Js.to_string input##.value)))

let createTextInput txt =
  let input = Dom_html.createInput ~_type:(Js.string "text") document in
  input##.value := Js.string txt ;
  ((input :> Dom_html.element Js.t), fun _ -> Js.to_string input##.value)

let createPercentageInput d =
  let d = max 0. (min 1. d) in
  let maxv = 1_000 in
  let maxvf = float_of_int maxv in
  let input = Dom_html.createInput ~_type:(Js.string "range") document in
  ignore (input##setAttribute (Js.string "min") (Js.string "0")) ;
  ignore (input##setAttribute (Js.string "max") (Js.string (string_of_int maxv))) ;
  input##.value := Js.string (string_of_int (int_of_float (maxvf *. d))) ;
  ((input :> Dom_html.element Js.t), fun _ ->
    (max 0. (min maxvf (float_of_string (Js.to_string input##.value)))) /. maxvf)

let createSwitch text texton textoff b f =
  let label = Dom_html.createLabel document in
  ignore (label##setAttribute (Js.string "class") (Js.string "switch")) ;
  let input = Dom_html.createInput ~_type:(Js.string "checkbox") document in
  input##.onchange := Dom_html.handler (fun _ -> f () ; Js._true) ;
  Dom.appendChild label input ;
  let span = Dom_html.createSpan document in
  ignore (span##setAttribute (Js.string "class") (Js.string "slider")) ;
  Dom.appendChild label span ;
  Dom.appendChild label (block_node (Text text)) ;
  let addText textClass =
    Option.may (fun text ->
      Dom.appendChild label (block_node (Text " ")) ;
      let node = block_node (Text (text)) in
      ignore (node##setAttribute (Js.string "class") (Js.string textClass)) ;
      Dom.appendChild label node) in
  addText "textswitchon" texton ;
  addText "textswitchoff" textoff ;
  let assign b = (Js.Unsafe.coerce input)##.checked := Js.bool b in
  assign b ;
  ((label :> Dom_html.element Js.t), assign, fun _ ->
    Js.to_bool (Js.Unsafe.coerce input)##.checked)

let createFileImport extensions prepare =
  let input = Dom_html.createInput ~_type:(Js.string "file") document in
  if extensions <> [] then
    ignore (input##setAttribute (Js.string "accept")
      (Js.string (String.concat ", " (List.map (fun e -> "." ^ e) extensions)))) ;
  ((input :> Dom_html.element Js.t), fun _ ->
    prepare () ;%lwt
    match Js.Optdef.to_option input##.files with
    | None -> Lwt.return ("", "")
    | Some files ->
      let rec aux l n =
        if n = files##.length then
          Lwt.return (List.rev l)
        else
          match Js.Opt.to_option (files##item n) with
          | None -> aux l (n + 1)
          | Some f ->
            let reader = new%js Js_of_ocaml.File.fileReader in
            let (cont, w) = Lwt.task () in
            reader##.onload := Dom.handler (fun _ ->
              let str =
                Js.to_string (Utils.assert_option __LOC__
                  (Js.Opt.to_option (File.CoerceTo.string (reader##.result)))) in
              Lwt.wakeup_later w (fun _ ->
                aux ((Js.to_string f##.name, str) :: l) (n + 1)) ;
              Js._true) ;
            reader##readAsText f ;
            let%lwt cont = cont in cont () in
      let%lwt l = aux [] 0 in
      Lwt.return (String.concat "," (List.map fst l),
                  String.concat "" (List.map snd l)))


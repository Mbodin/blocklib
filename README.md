
Blocklib is a small library for portable user interaction for OCaml.

It features [a common interface](src/inOut.mli), and two implementations:
- [a JavaScript one](js/),
- [a terminal one](native/).

Note that Blocklib is a very common library name: do double-check that this is indeed the library that you need.
It was named as-is because its main display unit is associated to the `block` type (nothing related to block-chain or this kind of thing).

To use the library, define a module parameterised by an `InOut.T` submodule.
For instance by creating a file `main.ml` as-is:
```ocaml
module Main (IO : InOut.T) = struct

    (* Your code *)

  end
```
Place this module in the `src` subfolder of your repository, along with a dune file that would look like this:
```
(library
  (public_name projectName)
  (name projectName)
  (libraries blocklib)
  (modes byte native))
```
The main module will be declare as a library despite containing all of the program logic.
This “library” will then be instantiated to create the wanted interface.
You can instantiate the program for as many interface as you want.

Then, to create a native output, create a `native` subfolder with the following dune file:
```
(executable
  (public_name projectName)
  (name projectName_native)
  (libraries projectName blocklib.native lwt.unix)
  (preprocess (pps lwt_ppx))
  (modes native))
```
and the following OCaml file:
```ocaml
module Main = ProjectName.Main.Main (Blocklib_native.InOut)

let _ = Lwt_main.run Main.main
```
Note the nested `Main.Main`: the first `Main` corresponds to the file `src/main.ml` created above, and the nested `Main` corresponds to the `Main` parameterised module defined inside this file.

To create a JavaScript output, create a `js` subfolder with the following dune file:
```
(executable
  (name main_js)
  (libraries projectName blocklib.js js_of_ocaml-lwt)
  (preprocess (pps lwt_ppx js_of_ocaml-ppx))
  (modes js))
```
and the following OCaml file:
```ocaml
module Main = ProjectName.Main.Main (Blocklib_js.InOut)
```
The JavaScript output then creates a `main.js` file, which expects to be placed in a webpage with a `<div id = "response"></div>` block, as well as two JavaScript functions `stopLoading` and `startLoading`.
See [the following project](https://github.com/Mbodin/tujkuko) for an example usage.


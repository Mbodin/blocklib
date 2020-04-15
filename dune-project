(lang dune 2.0)

(package
  (name blocklib)
  (synopsis "A basic interface library")
  (description "This program combines storylets to create a custom scenario.")
	(license AGPL-3.0-or-later)
	(maintainers "Martin Constantino–Bodin <martin.bodin@ens-lyon.org>")
	(source (github Mbodin/blocklib))
	(homepage "https://mbodin.github.io/blocklib/"))

(explicit_js_mode)

(using menhir 2.0)


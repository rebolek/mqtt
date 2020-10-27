Red[
	Title: "FUNK - Funky function"
	Author: "Boleslav Březovský"
	Usage: {
FUNK is functor that expands function dialect with following stuff:

* body

** /local

You can use /local refinement anywhere in code. Words and set-words
prefixed with (local will be added to /local in specs

* spec

** #expose

#expose will ignore /local and expose them to global context.
Useful for testing.
	}
]

funk: func [
	spec [block!]
	body [block!]
	/local local-mark locals locs expose? body-rule word length
][
	parse spec [
		any [
			ahead /local local-mark: skip
			copy locals to [refinement! | issue! | end]
		|	remove #expose (expose?: true)
		|	skip
		]
	]
	unless locals [locals: copy []]
	locs: clear []
	parse body body-rule: [
		some [
			ahead [/local [set-word! | word!]]
			remove skip set word skip (append locs to word! word)
		|	ahead [block! | paren!] into body-rule
		|	skip
		]
	]
	length: length? locals
	either expose? [
		remove/part local-mark 1 + length
	][
		append locals locs
		locals: unique locals
		either local-mark [
			change/part next local-mark locals length
		][
			append spec head insert locals /local
		]
	]
	func spec body
]

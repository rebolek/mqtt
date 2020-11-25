Red[]

; needs %mqtt-common.red bud be we assume it's loaded already

context [

	; -- variables

	value: none
	result: []

	; -- rules

	merge-paths: quote (unless block? value [value: append/only copy [] value])

	; -- functions

	output: func [cmd values][
		insert values to lit-word! cmd
		repend result values
	]

	set 'parse-mqtt funk [data /local value][
		clear result
		parse data [
			some [
			|	'pingreq (output 'pingreq [none none])
				'subscribe set value [block! | path!]
				merge-paths
			;	(repend result [to lit-word! 'subscribe none value])
				(output 'subscribe [none value])
			|	'unsubscribe set value [block! | path!]
				merge-paths
			;	(repend result [to lit-word! 'unsubscribe none value])
				(output 'unsubscribe [none value])
			]
		]
		result
	]
]

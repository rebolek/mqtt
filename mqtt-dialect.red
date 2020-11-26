Red[]

; needs %mqtt-common.red bud be we assume it's loaded already

context [

	; -- variables

	value: none
	result: []

	; -- rules

	merge-paths: quote (unless block? value [value: append/only clear [] value])

	; -- functions

	output: func [cmd values] [
		#TODO "This is so freaking complicated, I can't even"
		insert values compose [to lit-word! (to lit-word! cmd)]
		repend result values
	]

	set 'parse-mqtt funk [data] [
		clear result
		parse data [
			some [
				'pingreq (output 'pingreq [none none])
			|	'subscribe set value [block! | path!]
				merge-paths
				(output 'subscribe [none value])
			|	'unsubscribe set value [block! | path!]
				merge-paths
				(output 'unsubscribe [none value])
			]
		]
		probe result
	]
]

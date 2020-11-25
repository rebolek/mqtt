Red[]

; needs %mqtt-common.red bud be we assume it's loaded already

context [

	; -- variables

	value: none
	result: []

	; -- rules

	merge-paths: quote (unless block? value [value: append/only copy [] value])

	; -- functions

	set 'parse-mqtt funk [data][
		clear result
		parse data [
			some [
				'subscribe set value [block! | path!]
				merge-paths
				(repend result [to lit-word! 'subscribe none value])
			|	'unsubscribe set value [block! | path!]
				merge-paths
				(repend result [to lit-word! 'unsubscribe none value])
			]
		]
		result
	]
]

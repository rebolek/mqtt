Red[]

; needs %mqtt-common.red bud be we assume it's loaded already

context [

	; -- variables

	value: none
	result: []

	; -- rules

	; -- functions

	set 'parse-mqtt funk [data][
		clear result
		parse data [
			some [
				'subscribe set value path!
				(repend result [to lit-word! 'subscribe none to lit-path! value])
			]
		]
		result
	]
]

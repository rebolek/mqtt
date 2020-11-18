Red[

	Notes: [
		#commands

		message		make	process	status

		CONNECT		done	todo	(partially)
		CONNACK		done	done	(partially)
		PUBLISH		done	todo	(partially)
		PUBACK		todo	done	(partially)
		PUBREC		todo	todo
		PUBREL		todo	todo
		PUBCOMP		todo	todo
		SUBSCRIBE	done	todo	(partially)
		SUBACK		done	done	(make: untested done: partially)
		UNSUBSCRIBE	done	todo	(partially)
		UNSUBACK	todo	todo
		PINGREQ		done	todo
		PINGRESP	done	todo
		DISCONNECT	todo	todo
		AUTH		todo	todo

		#behavior

		QoS			todo
		sessions	todo


		#Usage

		##CONNECT

		make-message 'CONNECT none none ; empty flags
		make-message 'CONNECT [flags [flags here]] none

		##PUBLISH

		make-message 'PUBLISH "some/topic" "message"
		make-message 'PUBLISH ["some/topic"] "message"
		make-message 'PUBLISH ["some/topic" flags [qos 2]] "message"
	]
]

#include %funk.red
#include %mqtt-data.red
#include %mqtt-make.red
#include %mqtt-parse.red

state: context [
;	state: none
	type: none
	packet-id: none
	flags: none
	length: none
	taken: none		; number of bytes taken from message
]


; -- datatype functions -----------------------------------------------------

enc-string: func [string [string!]][
	string: to binary! string
;	insert string skip to binary! length? string 2
	insert string enc-int16 length? string
	string
]

dec-string: funk [data [binary!]][
	/local length: to integer! take/part data 2
	state/taken: 2 + length
	to string! take/part data length
]

enc-int: func [value [integer!] /local out enc-byte][
	out: copy #{}
	until [
		enc-byte: value // 128
		value: to integer! value / 128
		if value > 0 [enc-byte: enc-byte or 128]
		append out enc-byte
		value = 0
	]
	out
]

enc-int8: func [value [integer!] /local out][
	skip to binary! value 3
]

enc-int16: func [value [integer!] /local out][
	skip to binary! value 2
]

dec-int: func [data [binary!] /local multiplier value enc-byte][
	multiplier: 1
	value: 0
	state/taken: 0
	until [
		enc-byte: take data
		state/taken: state/taken + 1
		value: (enc-byte and 127) * multiplier + value
		if multiplier > 2'097'152 [ ; 128 ** 3
			do make error! "Malformed variable byte integer"
		]
		multiplier: multiplier << 7
		zero? enc-byte and 128
	]
	value
]

dec-int16: func [data [binary!]][to integer! take/part data state/taken: 2]

dec-int32: func [data [binary!]][to integer! take/part data state/taken: 4]

; -- end --

; -- support functions

context [
	id: -1
	set 'make-packet-id func [/random][
		if random [return enc-int16 random 65535]
		id: id + 1
		if id = 65536 [id: -1]
		id
	]
]


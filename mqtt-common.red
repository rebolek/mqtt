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

make-packet-id: func [][
	; TODO: Now it returns random number but incremental ID may be better
	enc-int16 random 65535
]

; -- send message -----------------------------------------------------------

.: context [

var-header: #{}	; needs to be accessible from other functions
payload: #{}	; dtto
props: #{}
out: #{}

set 'make-message funk [
	type	[word!]
	header	[none! block! string! path!]
	message	[any-type!]
][
#NOTES [
	working-support: PINGREQ
]
	clear out
	clear var-header
	clear props
	clear payload
	/local qos: 0

	; -- fixed header

	; control packet type
	/local packet-type: index? find message-types type
	/local flags: select reserved-flags type
	; PUBLISH message doesn't have reserved flags, we get flags from header
	unless flags [
		flags: either flags: select header 'flags [
			; flags are just words (for DUP and RETAIN) 
			; or word followed by value (QoS)
			/local dup: pick [0 1] not find flags 'dup
			/local retain: pick [0 1] not find flags 'retain
			qos: any [select flags 'qos 0] ; TODO: error handling
			(dup << 3) or (qos << 2) or retain
		][
		;		flags are not required, if not present, set them to zero
			0
		]
	]
	/local byte: (packet-type << 4) or flags
	append out byte

	; -- variable header

	; ---- PUBLISH: topic name (3.2.2.1)
	if type = 'PUBLISH [append var-header enc-string form header]

	; ---- packet identifier
	if any [
		all [type = 'PUBLISH qos > 0]
		find [
			PUBACK PUBREC PUBREL PUBCOMP SUBSCRIBE SUBACK UNSUBSCRIBE UNSUBACK
		] type
	] [
		/local packet-id: make-packet-id
		state/packet-id: to integer! packet-id
		print ["Packet ID:" to integer! packet-id packet-id]
		append var-header packet-id
	]

	; ---- packet identifier
	if /local type-id: find [
		CONNECT CONNACK PUBLISH PUBACK PUBREC PUBREL PUBCOMP SUBSCRIBE
		SUBACK UNSUBSCRIBE UNSUBACK DISCONNECT AUTH
	] type [
		; property length
		; TODO set var-byte-int propert length
	]

	; now variable header and properties will be done
	switch type [
		CONNECT [
			flags: any [
				all [
					header
					select header 'flags ; TODO: use parse
				]
				[]
			]
			make-header/connect flags
		]
		CONNACK [make-header/connack]
		SUBSCRIBE [make-header/subscribe]
		SUBACK [make-header/suback]
		UNSUBSCRIBE [make-header/unsubscribe]
		PUBLISH [
			/local topic: either string? header [header][
				first find header string!
			]
			make-header/publish topic
		]
	]
	
	; append properties when required
	if find [
		CONNECT CONNACK PUBLISH PUBACK PUBREC PUBREL PUBCOMP SUBSCRIBE
		SUBACK UNSUBSCRIBE UNSUBACK DISCONNECT AUTH
	] type [
		append var-header enc-int length? props
		append var-header props
	]

	switch type [
		CONNECT [make-payload/connect flags]
		SUBSCRIBE [make-payload/subscribe message]
		SUBACK [make-payload/suback]
		UNSUBSCRIBE [make-payload/unsubscribe message]
		PUBLISH [make-payload/publish message]
	]

	append out enc-int (length? var-header) + (length? payload)
	append out var-header
	append out payload
	out
]

; -- MAKE-HEADER --

make-header: context [

	connect: funk [
		flags ; TODO: should take properties, not just flags
		/local value
	][
		; -- CONNECT Variable Header

		; The Variable Header for the CONNECT Packet contains 
		; the following fields in this order: 
		;
		; Protocol Name, Protocol Level, Connect Flags, Keep Alive, and Properties.

		; append var-header enc-string "MQTT"	; Protocol Name
		; append var-header #{05}	; Protocol Version

		append var-header #{00044D51545405} ; encoded string MQTT + 05 (version)

		/local connect-flags: #{00}
		parse flags [
			any [
				'clean (connect-flags: connect-flags or #{02})
			|	'will (connect-flags: connect-flags or #{04})
			|	'qos set value integer! (
					value: skip to binary! value << 3 3
					connect-flags: connect-flags or #{04} or value
				)
			|	'retain (connect-flags: connect-flags or #{20})
			|	'username (connect-flags: connect-flags or #{80})
			|	'password (connect-flags: connect-flags or #{40})
			]
		]
		append var-header connect-flags

		append var-header #{0000}	; TODO: Keep Alive value (seconds)

		; -- Properties

		; ---- session expiry interval (opt) [11h 4 byte]
		;append props #{1100000000}

		; ---- receive maximum (opt) [21h 2 byte]
		;append props #{21FFFF}

		; ---- maximum packet size (opt) [27h 4 byte]
		;append props #{270000FFFF}

		; ---- topic alias maximum (opt) [22h 2 byte]
		;append props #{22FFFF}

		; ---- request response information (opt) [19h 1 byte logic]
		;append props #{1901} ; zero or one

		; ---- request problem information (opt) [17h 1 byte logic]
		;append props #{1701} ; zero or one

		; ---- user property (any) [26h string-pair]
		;append props #{}

		; ---- authentication method (opt) [15h string]
		;append props #{}

		; ---- authentication data (opt) [16 1 byte]  - auth method must be included
	]

	connack: funk [][
		; 3.2.2
		; -- connect ackonwledge flags 3.2.2.1
		/local caf: 0 ; TODO: 1 when session present (server management)

		; -- connect reason code 3.2.2.2
		/local crc: 0 ; TODO: select from CONNECT-REASON-CODES based on what's required

		; -- properties 3.2.2.3

		; ---- session expiry interval (opt) [11h 4 byte]
		;append props #{1100000000}

		; ---- receive maximum (opt) [21h 2 byte]
		;append props #{21FFFF}

		; ---- maximum QoS (opt) [24h 1 byte]
		append props #{2400} ; NOTE: No QoS supported yet. If not present,
							;		it means QoS = 2 and that's certainly not true ;)

		; ---- retain available (opt) [25h 1 byte]
		;append props #{2500}

		; ---- maximum packet size (opt) [27h 4 byte]
		;append props #{270000FFFF}

		; ---- assigned client identifier (opt) [12h string]

		; ---- topic alias maximum (opt) [22h 2 byte]
		;append props #{22FFFF}

		; ---- reason string (opt) [1Fh string]
		;append props #{1F}
		;append props third find connect-reason-codes crc

		; ---- wildcard subscription available (opt) [28h 1 byte]

		; ---- subscription identifiers available (opt) [29h 1 byte]

		; ---- shared subscription available (opt) [2Ah 1 byte]

		; ---- server keep alive (opt) [13h 2 byte]

		; ---- response information (opt) [1Ah string]

		; ---- server reference (opt) [1Ch string]

		; ---- authentication method (opt) [15h string]
		;append props #{}

		; ---- authentication data (opt) [16 1 byte]  - auth method must be included
	]

	subscribe: funk [][
		; -- subscription identifier
		#TODO [opt 0Bh var-int] ; can't be zero

		; -- user property
		#TODO [any 26h 2 string]
	]

	suback: funk [][
		; ---- reason string
		#TODO [1Fh string]

		; ---- user property
		#TODO [26h 2 string]
	]

	unsubscribe: funk [][
		; ---- user property
		; [any [26h 2 string]]
	]

	publish: funk [header][
		; ---- payload format indicator
		; [01h [0 unspecified-bytes | 1 utf8-string]]

		; ---- message expiry interval
		; [02h int32]

		; ---- topic alias
		; [23h int16]

		; ---- response topic
		; [08h string]

		; ---- correlation data
		; [09h binary]

		; ---- user property
		; [26h 2 string]

		; ---- subscription identifier
		; [0Bh var-int]

		; ---- content type
		; [03h string]
	]

]

; -- end of MAKE-HEADER context --

; -- MAKE-PAYLOAD context --

make-payload: context [

	connect: funk [flags][
		;	The Payload of the CONNECT packet contains one or more length-prefixed
		;	fields, whose presence is determined by the flags in the Variable Header.
		;	These fields, if present, MUST appear in the order:
		;		Client Identifier (MUST be present)
		;		Will Properties
		;		Will Topic
		;		Will Payload
		;		User Name
		;		Password

		; -- client identifier
		append payload enc-string "redmqttv0" ; TODO: should be different for each client

		; -- will properties (if will flag = 1)

		; ---- property length (varlenint)

		; ---- will delay interval [18h 4 byte]

		; ---- payload format indicator [01h 1 byte logic]

		; ---- message expiry interval [02h 4 byte]

		; ---- content type [03h string]

		; ---- response topic [08h string]

		; ---- correlation data [09h binary]

		; ---- user property [26h string pair]

		; -- will topic [string] (if will flag = 1)

		; -- will payload [binary] (if will flag = 1)

		; -- user name [string] (if user name flag = 1)

		; -- password [string] (if password flag = 1)
	]

	subscribe: funk [topic [string! path! block!]][
		topic: append clear [] topic
		foreach /local tpc topic [
			append payload enc-string form tpc
			/local sub-opt: 0
			sub-opt: sub-opt or (0 << 6)	; [2 bit] TODO: QoS
			sub-opt: sub-opt or (0 << 5)	; [1 bit] TODO: No Local option
			sub-opt: sub-opt or (0 << 4)	; [1 bit] TODO: Retain As Published
			sub-opt: sub-opt or (0 << 2)	; [2 bit] TODO: Retain Handling
			sub-opt: sub-opt or 0			; [2 bit] Reserved
			append payload sub-opt
		]
	]

	suback: funk [][
		; -- payload
		#TODO 'SUBACK-REASON-CODES
		append payload #{00} ; placeholder: Granted QoS 0
	]

	unsubscribe: funk [topic [string! path! block!]][
		topic: append clear [] topic
		foreach /local tpc topic [
			append payload enc-string form tpc
		]
	]

	publish: funk [data][
	; ---- publish payload
		unless any [string? data binary? data][data: form data]
		append payload data
	]

; -- end of MAKE-PAYLOAD context --
]
; -- end of anynomouc context for making messages
]

; -- receive message --------------------------------------------------------

context [
session-present?:
reason-code:
	none

parse-message: funk [msg][
	msg: copy msg ; NOTE just for testing
	; -- packet type
	/local byte: take msg
	state/type: pick message-types byte >> 4
	state/flags: byte and 0Fh
	state/length: dec-int msg

	print ["Type:" state/type]
;	state/state: state/type

	; -- variable header
	;
	switch state/type [
		CONNACK	[process-connack msg]
		SUBACK	[process-suback msg]
		PUBLISH	[process-publish msg]
		PINGREQ	[process-ping msg]
	]

	reduce [
		state/type
		session-present?
		reason-code
	]
]

#TODO "move process messages to PROCESS context"

process-connack: func [msg][
	; The Variable Header of the CONNACK Packet contains the following
	; fields in the order:
	;
	; - Connect Acknowledge Flags
	; - Connect Reason Code
	; - Properties

	; ---- connect acknowledge flags
	/local byte: take msg
	if byte > 1 [do make error! "Connect acknowledge flag bits 1-7 aren't 0"]
	session-present?: make logic! byte and 1

	; ---- connect reason code
	reason-code: select connect-reason-codes take msg

	; -- CONNACK properties
	/local length: probe dec-int msg
	/local data: take/part msg length
	while [not empty? data][
		switch take data [
			11h [ ; session expiry interval
				value: dec-int32 data
				print ["session expiry interval:" value]
			]
			21h [ ; recive maximum
				value: dec-int16 data
				print ["receive maximum:" value]
			]
			24h [ ; maximum QoS
				value: take data
				print ["QoS:" value]
			]
			25h [ ; retain available
				value: take data
				print ["Retain available:" value]
			]
			27h [ ; maximum packet size
				value: dec-int32 data
				print ["Max packet size:" value]
			]
			12h [ ; assigned client identifier
				value: dec-string data
				print ["Client identifier:" value]
			]
			22h [ ; topic alias maximum
				value: dec-int16 data
				print ["Topic alias maximum:" value]
			]
			1Fh [ ; reason string
				value: dec-string data
				print ["Reason string:" value]
			]
			26h [ ; user property
				value: dec-string data
				print ["User prop key:" value]
				value: dec-string data
				print ["User prop data:" value]
			]
			2Ah [ ; shared subscription available
				value: take data
				print ["Shared sub avail:" value]
			]
			13h [ ; keep server alive
				value: dec-int16 data
				print ["Keep server alive:" value]
			]
			1Ah [ ; response information
				value: dec-string data
				print ["Response information:" value]
			]
			1Ch [ ; server reference
				value: dec-string data
				print ["Server eference:" value]
			]
			15h [ ; authentication method
				value: dec-string data
				print ["Auth method:" value]
			]
			16h [ ; authentication data
				length: dec-int data
				value: take/part data length
				print ["Auth data length:" length]
			]
		]
	]
]

process-suback: func [msg][

	; -- SUBACK variable header

	; ---- Packet identifier

	/local packet-id: dec-int16 msg
	either equal? packet-id state/packet-id [
		print ["SUBACK: Packet ID:" packet-id]
	][
		print ["SUBACK Packet ID:" packet-id "Expected:" state/packet-id]
		do make error! "Packet identifier differs"
	]

	; ---- Properties

	/local length: dec-int16 msg
	while [length > 0][
		switch msg/1 [
			1Fh [ ; reason string
				/local reason: dec-string msg
				print ["Reason:" reason]
				; 3: 1 byte identifier + 2 bytes string length
				length: length - 3 - length? to binary! reason
			]
			26h [ ; user property
				/local key: dec-string msg
				/local value: dec-string msg
				print ["User prop:" key #":" value]
				; 5: 1 byte identifier + 2*2 bytes string length
				length: length - 5 - (length? to binary! key) - (length? to binary! value)
			]
		]
	]

	; -- SUBACK Payload
	until [
		; as it's possible to SUBSCRIBE to multiple topics
		; server may send multiple payloads, one for each topic
		; TODO: Store SUBSCRIBE topics so payloads can be assigned to topics
		/local reason: select suback-reason-codes take msg

		empty? msg
	]

]

process-publish: funk [
	msg
][
	/local flags: state/flags
	/local length: state/length
	/local dup: flags >> 3
	/local qos: (flags and 7) >> 1
	/local retain: flags and 1

	; -- variable header

	; ---- topic name

	/local topic-name: dec-string msg
	length: length - state/taken

	; ---- packet identifier

	if qos > 0 [
		/local packet-id: dec-int16 msg
		length: length - state/taken
	]

	; ---- publish properties

	/local prop-length: dec-int msg

	props: take/part msg prop-length

	; TODO: parse props

	length: length - state/taken

	; -- payload

	/local payload: take/part msg length

	parse payload [
		some [
	; ------ payload format indicator
			01h copy value skip
	; ------ message expiry interval
		|	02h copy value 4 skip
	; ------ topic alias
		|	23h copy value 2 skip
	; ------ response topic
		|	08h copy length 2 skip (length: to integer! length)
				copy value length skip
	; ------ correlation data
		|	09h copy length 2 skip (length: to integer! length)
				copy value length skip
	; ------ user property
		|	26h copy length 2 skip (length: to integer! length)
				copy value length skip
				copy length 2 skip (length: to integer! length)
				copy value length skip
	; ------ subscription identifier
		|	0Bh var-int-rule
	; ------ content type
		|	03h copy length 2 skip (length: to integer! length)
				copy value length skip
		]
	]

	; ------ payload format indicator

	; [01h [0 unspecified-bytes | 1 utf8-string]]

	; ------ message expiry interval

	; [02h int32]

	; TODO: Let's for now expect that the message is UTF-8 string
	payload: to string! payload

	print [
		"TOPIC:" topic-name newline
		"LNGTH:" length newline
		"PRLEN:" prop-length newline
		"PAYLD:" payload
	]

]

process-ping: func [msg][
	
]
; ---- Context ends here
]





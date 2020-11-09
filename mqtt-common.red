Red[]

#include %funk.red
#include %mqtt-data.red

mqtt: context [
	state: none
	type: none
	packet-id: none
	flags: none
	length: none
]


; -- datatype functions -----------------------------------------------------

enc-string: func [string [string!]][
	string: to binary! string
;	insert string skip to binary! length? string 2
	insert string enc-int16 length? string
	string
]

dec-string: funk [data [binary!]][
	/local length: take/part data 2
	to string! take/part data to integer! length
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
	until [
		enc-byte: take data
		value: (enc-byte and 127) * multiplier + value
		if multiplier > 2'097'152 [ ; 128 ** 3
			do make error! "Malformed variable byte integer"
		]
		multiplier: multiplier << 7
		zero? enc-byte and 128
	]
	value
]

dec-int16: func [data [binary!]][to integer! take/part data 2]

dec-int32: func [data [binary!]][to integer! take/part data 4]

; -- end --

; -- support functions

make-packet-id: func [][
	; TODO: Now it returns random number but incremental ID may be better
	enc-int16 random 65535
]

; -- send message -----------------------------------------------------------

make-message: funk [
	type [word!]
	message
	/local packet-type flags byte
][
	out: copy #{}
	; control packet type
	packet-type: index? find message-types type
	flags: select reserved-flags type
	byte: (packet-type << 4) or flags
	append out byte
	; remaining length
	; TODO: append 2 bytes of remaining length
	; variable header
	; packet identifier
	if find [
		PUBLISH PUBACK PUBREC PUBREL PUBCOMP
		SUBSCRIBE SUBACK UNSUBSCRIBE UNSUBACK
	] type [
		append out make-packet-identifier type
	]
	; properties
	if /local type-id: find [
		CONNECT CONNACK PUBLISH PUBACK PUBREC PUBREL PUBCOMP SUBSCRIBE
		SUBACK UNSUBSCRIBE UNSUBACK DISCONNECT AUTH
	] type [
		; property length
		; TODO set var-byte-int propert length
	]
	out
]

make-conn-header: funk [
	flags
	/local value
][
	; -- CONNECT Variable Header

	; The Variable Header for the CONNECT Packet contains 
	; the following fields in this order: 
	;
	; Protocol Name, Protocol Level, Connect Flags, Keep Alive, and Properties.

	out: copy #{}

	append out enc-string "MQTT"	; Protocol Name
	append out #{05}	; Protocol Version

	connect-flags: #{00}
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
	append out connect-flags

	append out #{0000}	; TODO: Keep Alive value (seconds)

	; -- Properties

	props: copy #{}

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

	insert props enc-int length? props

	append out props

	out
]

make-payload: funk [][

;	The Payload of the CONNECT packet contains one or more length-prefixed
;	fields, whose presence is determined by the flags in the Variable Header.
;	These fields, if present, MUST appear in the order:
;		Client Identifier (MUST be present)
;		Will Properties
;		Will Topic
;		Will Payload
;		User Name
;		Password

	/local payload: clear #{}

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

make-subscribe-message: funk [
	topic [string! path! block!]
][
	/local length: 0

	; -- var header
	/local var-header: clear #{}
	; ---- packet identifier

	; TODO: should be separate function
	; create unique packet identifier (PI)
	; there must be PI handling, so PIs can be reused

	/local packet-id: make-packet-id
	mqtt/packet-id: to integer! packet-id
	print ["Packet ID:" to integer! packet-id packet-id]
	append var-header packet-id

	; ---- properties

	/local vh-props: clear #{}
	
	; ------ subscription identifier
	[opt 0Bh var-int] ; can't be zero

	; ------ user property
	[any 26h string string]
	
	append var-header enc-int length? vh-props
	append var-header vh-props

	length: length + length? var-header

	; ---- subscripe payload
	/local payload: clear #{}
	topic: append clear [] topic
	foreach /local tpc topic [
		/local data: form tpc
		append payload enc-int16 length? data
		append payload data
		/local sub-opt: 0
		sub-opt: sub-opt or (0 << 6)	; [2 bit] TODO: QoS
		sub-opt: sub-opt or (0 << 5)	; [1 bit] TODO: No Local option
		sub-opt: sub-opt or (0 << 4)	; [1 bit] TODO: Retain As Published
		sub-opt: sub-opt or (0 << 2)	; [2 bit] TODO: Retain Handling
		sub-opt: sub-opt or 0			; [2 bit] Reserved
		append payload sub-opt
	]

	length: length + length? payload

	rejoin [ #{}
		82h	; -- SUBSCRIBE header
		enc-int length
		var-header
		payload
	]
]
; -- end --

make-publish-message: funk [
	topic-name [path! string!]
	payload
][
	; TODO: get this from external sources
	/local dup: 0
	/local qos: 0
	/local retain: 0

	/local fixed-header: (3 << 4) or (dup << 3) or (qos << 2) or retain

	; -- variable header
	;	The Variable Header of the PUBLISH Packet contains 
	;	the following fields in the order: 
	;	- Topic Name
	;	- Packet Identifier
	;	- Properties

	/local var-header: clear #{}

	; ---- topic name
	; [string]

	append var-header enc-string form topic-name

	; ---- packet identifier
	; [if (qos > 0) int16]

	; TODO

	; ---- properties

	/local props: clear #{}

	; ------ payload format indicator

	; [01h [0 unspecified-bytes | 1 utf8-string]]

	; ------ message expiry interval

	; [02h int32]

	; ------ topic alias

	; [23h int16]

	; ------ response topic

	; [08h string]

	; ------ correlation data

	; [09h binary]

	; ------ user property

	; [26h 2 string]

	; ------ subscription identifier

	; [0Bh var-int]

	; ------ content type

; [03h string]


	append var-header enc-int length? props
	append var-header props

	; ---- publish payload

	unless any [string? payload binary? payload][payload: form payload]

	rejoin [
		#{}
		fixed-header
		enc-int (length? var-header) + (length? payload)
		var-header
		payload
	]

]

; -- receive message --------------------------------------------------------

; --- TODO: Context start here

session-present?:
reason-code:
	none

parse-message: funk [msg][
	msg: copy msg ; NOTE just for testing
	; -- packet type
	/local byte: take msg
	mqtt/type: pick message-types byte >> 4
	mqtt/flags: byte and 0Fh
	mqtt/length: dec-int msg

	print ["Type:" type]
	mqtt/state: mqtt/type

	; -- variable header
	;
	switch type [
		CONNACK	[process-connack msg]
		SUBACK	[process-suback msg]
		PUBLISH	[process-publish msg]
	]

	reduce [
		type
		session-present?
		reason-code
	]
]

#TODO "all ~process~ functions shoul dbe in same context"

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
	either equal? packet-id mqtt/packet-id [
		print ["SUBACK: Packet ID:" packet-id]
	][
		print ["SUBACK Packet ID:" packet-id "Expected:" mqtt/packet-id]
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
	/local dup: flags >> 3
	/local qos: (flags and 7) >> 1
]

; ---- TODO: Context ends here





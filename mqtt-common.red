Red[]

#include %funk.red

encode-string: func [string [string!]][
	string: to binary! string
	insert string skip to binary! length? string 2
	string
]

decode-string: func [data [binary!]][
	
]

encode-integer: func [value [integer!] /local out enc-byte][
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

decode-integer: func [data [binary!] /local multiplier value enc-byte][
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

message-types: [
	CONNECT
	CONNACK
	PUBLISH
	PUBACK
	PUBREC
	PUBREL
	PUBCOMP
	SUBSCRIBE
	SUBACK
	UNSUBSCRIBE
	UNSUBACK
	PINGREQ
	DISCONNECT
	AUTH
]

reserved-flags: [
	CONNECT	0
	CONNACK	0
	PUBACK	0
	PUBREC	0
	PUBREL	2
	PUBCOMP	0
	SUBSCRIBE	2
	SUBACK	0
	UNSUBSCRIBE	2
	UNSUBACK	0
	PINGREQ	0
	PINGRESP	0
	DISCONNECT	0
	AUTH	0
]

make-message: func [
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
	if find [
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

	append out encode-string "MQTT"	; Protocol Name
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

	insert props encode-integer length? props

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

	append payload encode-string "redmqttv0" ; TODO: should be different for each client

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

make-packet-identifier: func [type [word!]][
	; TODO: make proper packet identifier
	#{1234}
]

properties: [
	PUBLISH will-properties [
		1 payload-format-indicator				[byte]
		2 message-expiry-interval				[4 byte]
		3 content-type							[string]
		8 response-topic						[string]
		9 correlation-data						[binary]
	]
	PUBLISH SUBSCRIBE [
		11 subscription-identifier				[var-byte-int]
	]
	CONNECT CONNACK DISCONNECT [
		17 session-expiry-interval				[4 byte] 
	]
	CONNACK [
		18 assigned-client-identifier			[string]
		19 server-keep-alive					[2 byte]
		26 response-information					[string]
	]
	CONNECT CONNACK AUTH [
		21 authentication-method				[string]
		22 authentication-data					[binary]
	]
	CONNECT [
		23 request-problem-information			[byte]
		25 request-response-information			[byte]
	]
	will-properties [
		24 will-delay-interval					[4 byte]
	]
	CONNACK DISCONNECT [
		28 server-reference						[string]
	]
	CONNACK PUBACK PUBREC PUBREL PUBCOMP SUBACK UNSUBACK DISCONNECT AUTH [
		31 reason-string						[string string]
	]
	CONNECT CONNACK [
		33 receive-maximum						[2 byte]
		34 topic-alias-maximum					[2 byte]
		39 maximum-packet-size					[4 byte]
	]
	CONNECT CONNACK PUBLISH will-properties PUBACK PUBREC PUBREL PUBCOMP
	SUBSCRIBE SUBACK UNSUBSCRIBE UNSUBACK DISCONNECT AUTH [
		38 user-property						[string string]
	]
	CONNACK [
		36 maximum-qos							[byte]
		37 retain-available						[byte]
		40 wildcard-subscription-available		[byte]
		41 subscription-identifier-available	[byte]
		42 shared-subscription-available		[byte]
	]
]


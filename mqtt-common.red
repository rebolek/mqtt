Red[]

#include %funk.red
#include %mqtt-data.red

encode-string: func [string [string!]][
	string: to binary! string
	insert string skip to binary! length? string 2
	string
]

decode-string: funk [data [binary!]][
	/local length: take/part data 2
	to string! take/part data to integer! length
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

decode-short-int: func [data [binary!]][to integer! take/part data 2]

decode-long-int: func [data [binary!]][to integer! take/part data 4]


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

parse-message: funk [msg][
	msg: copy msg ; NOTE just for testing
	; -- packet type
	/local byte: take msg
	/local type: pick message-types byte >> 4
	/local flags: byte and 0Fh
	/local length: decode-integer msg

	; -- variable header
	;
	; The Variable Header of the CONNACK Packet contains the following
	; fields in the order: 
	;
	; - Connect Acknowledge Flags
	; - Connect Reason Code
	; - Properties

	; ---- connect acknowledge flags
	byte: take msg
	if byte > 1 [do make error! "Connect acknowledge flag bits 1-7 aren't 0"]
	/local session-present?: make logic! byte and 1

	; ---- connect reason code
	reason-code: select connect-reason-codes take msg

	; -- CONNACK properties
	length: probe decode-integer msg

	data: take/part msg length
	while [not empty? data][
		switch take data [
			11h [ ; session expiry interval
				value: decode-long-int data
				print ["session expiry interval:" value]
			]
			21h [ ; recive maximum
				value: decode-short-int data
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
				value: decode-long-int data
				print ["Max packet size:" value]
			]
			12h [ ; assigned client identifier
				value: decode-string data
				print ["Client identifier:" value]
			]
			22h [ ; topic alias maximum
				value: decode-short-int data
				print ["Topic alias maximum:" value]
			]
			1Fh [ ; reason string
				value: decode-string data
				print ["Reason string:" value]
			]
			26h [ ; user property
				value: decode-string data
				print ["User prop key:" value]
				value: decode-string data
				print ["User prop data:" value]
			]
			2Ah [ ; shared subscription available
				value: take data
				print ["Shared sub avail:" value]
			]
			13h [ ; keep server alive
				value: decode-short-int data
				print ["Keep server alive:" value]
			]
			1Ah [ ; response information
				value: decode-string data
				print ["Response information:" value]
			]
			1Ch [ ; server reference
				value: decode-string data
				print ["Server eference:" value]
			]
			15h [ ; authentication method
				value: decode-string data
				print ["Auth method:" value]
			]
			16h [ ; authentication data
				length: decode-integer data
				value: take/part data length
				print ["Auth data length:" length]
			]

		]	
	]

	reduce [
		type
		session-present?
	]
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



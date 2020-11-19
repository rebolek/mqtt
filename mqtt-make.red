Red[]

; -- send message -----------------------------------------------------------

.: context [

	var-header: #{}	; needs to be accessible from other functions
	payload: #{}	; dtto
	props: #{}
	out: #{}
	flags: none

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
		flags: select reserved-flags type
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

		if type = 'CONNECT [
			; TODO: This is something that should be done much better
			flags: any [
				all [
					header
					select header 'flags ; TODO: use parse
				]
				[]
			]
		]
		if find [PUBLISH UNPUBLISH ] type [
			; TODO: Again, this is a piece of code I ashamed of
			;		Topic should't be context-global, what is this OMG
			topic: either string? header [header][
				first find header string!
			]
		]
		probe var-header
		do select headers type
		probe var-header
		
		; append properties when required
		if find [
			CONNECT CONNACK PUBLISH PUBACK PUBREC PUBREL PUBCOMP SUBSCRIBE
			SUBACK UNSUBSCRIBE UNSUBACK DISCONNECT AUTH
		] type [
			append var-header enc-int length? props
			append var-header props
		]

		; -- payload
		/local act: select payloads type
		act

		; -- put everything together
		append out probe enc-int (length? var-header) + (length? payload)
		append out probe var-header
		append out probe payload
		out
	]

	; -- MAKE-HEADER --

	headers: context [

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
print "APP"
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

	payloads: context [

		connect: funk [][
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

		subscribe: funk [][
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

		unsubscribe: funk [][
			topic: append clear [] topic
			foreach /local tpc topic [
				append payload enc-string form tpc
			]
		]

		publish: funk [][
		; ---- publish payload
			append payload form msg
		]

	; -- end of MAKE-PAYLOAD context --
	]
; -- end of anynomouc context for making messages
]


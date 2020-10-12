Red[
	Title: "MQTT server"
	Author: "Boleslav Březovský"
]

encode-string: func [string [string!]][
	string: to binary! string
	insert string skip to binary! length? string 2
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
]

make-packet-identifier: func [type [word!]][
	; TODO: make proper packet identifier
	#{1234}
]

properties: [
	PUBLISH will-properties [
		1 payload-format-indicator	[byte]
		2 message-expiry-interval	[4 byte]
		3 content-type				[string]
		8 response-topic			[string]
		9 correlation-data			[binary]
	]
	PUBLISH SUBSCRIBE [
		11 subscription-identifier	[var-byte-int]
	]
	CONNECT CONNACK DISCONNECT [
		17 session-expiry-interval	[4 byte] 
	]
	CONNACK [
		18 assigned-client-identifier	[string]
		19 server-keep-alive			[2 byte]
		26 response-information			[string]
	]
	CONNECT CONNACK AUTH [
		21 authentication-method		[string]
		22 authentication-data			[binary]
	]
	CONNECT [
		23 request-problem-information	[byte]
		25 request-response-information	[byte]
	]
	will-properties [
		24 will-delay-interval			[4 byte]
	]
	CONNACK DISCONNECT [
		28 server-reference			[string]
	]
	CONNACK PUBACK PUBREC PUBREL PUBCOMP SUBACK UNSUBACK DISCONNECT AUTH [
		31 reason-string				[string string]
	]
	CONNECT CONNACK [
		33 receive-maximum				[2 byte]
		34 topic-alias-maximum			[2 byte]
		39 maximum-packet-size			[4 byte]
	]
	CONNECT CONNACK PUBLISH will-properties PUBACK PUBREC PUBREL PUBCOMP
	SUBSCRIBE SUBACK UNSUBSCRIBE UNSUBACK DISCONNECT AUTH [
		38 user-property				[string string]
	]
	CONNACK [
		36 maximum-qos					[byte]
		37 retain-available				[byte]
		40 wildcard-subscription-available		[byte]
		41 subscription-identifier-available	[byte]
		42 shared-subscription-available		[byte]
	]
]


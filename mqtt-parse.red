Red[]

; -- receive message --------------------------------------------------------

; --- Context start here

context [

	session-present?:
	reason-code:
	msg:
		none

	parse-message: funk [message][
		message: copy message ; NOTE just for testing
		msg: message
		; -- packet type
		/local byte: take msg
		state/type: pick message-types byte >> 4
		state/flags: byte and 0Fh
		state/length: dec-int msg

		print ["Type:" state/type]

		; -- parse variable header
		do select types state/type

		reduce [
			state/type
			session-present?
			reason-code
		]
	]

	parse-properties: func [][
		switch take data [
			11h [ ; session expiry interval
				value: dec-int32 data
				print ["session expiry interval:" value]
			]
			12h [ ; assigned client identifier
				value: dec-string data
				print ["Client identifier:" value]
			]
			13h [ ; keep server alive
				value: dec-int16 data
				print ["Keep server alive:" value]
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
			1Ah [ ; response information
				value: dec-string data
				print ["Response information:" value]
			]
			1Ch [ ; server reference
				value: dec-string data
				print ["Server eference:" value]
			]
			1Fh [ ; reason string
				value: dec-string data
				print ["Reason string:" value]
			]
			21h [ ; receive maximum
				value: dec-int16 data
				print ["receive maximum:" value]
			]
			22h [ ; topic alias maximum
				value: dec-int16 data
				print ["Topic alias maximum:" value]
			]
			24h [ ; maximum QoS
				value: take data
				print ["QoS:" value]
			]
			25h [ ; retain available
				value: take data
				print ["Retain available:" value]
			]
			26h [ ; user property
				value: dec-string data
				print ["User prop key:" value]
				value: dec-string data
				print ["User prop data:" value]
			]
			27h [ ; maximum packet size
				value: dec-int32 data
				print ["Max packet size:" value]
			]
			2Ah [ ; shared subscription available
				value: take data
				print ["Shared sub avail:" value]
			]
		]
	]

	types: context [

		connack: func [][
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
					12h [ ; assigned client identifier
						value: dec-string data
						print ["Client identifier:" value]
					]
					13h [ ; keep server alive
						value: dec-int16 data
						print ["Keep server alive:" value]
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
					1Ah [ ; response information
						value: dec-string data
						print ["Response information:" value]
					]
					1Ch [ ; server reference
						value: dec-string data
						print ["Server eference:" value]
					]
					1Fh [ ; reason string
						value: dec-string data
						print ["Reason string:" value]
					]
					21h [ ; receive maximum
						value: dec-int16 data
						print ["receive maximum:" value]
					]
					22h [ ; topic alias maximum
						value: dec-int16 data
						print ["Topic alias maximum:" value]
					]
					24h [ ; maximum QoS
						value: take data
						print ["QoS:" value]
					]
					25h [ ; retain available
						value: take data
						print ["Retain available:" value]
					]
					26h [ ; user property
						value: dec-string data
						print ["User prop key:" value]
						value: dec-string data
						print ["User prop data:" value]
					]
					27h [ ; maximum packet size
						value: dec-int32 data
						print ["Max packet size:" value]
					]
					2Ah [ ; shared subscription available
						value: take data
						print ["Shared sub avail:" value]
					]
				]
			]
		]
	]

	suback: func [][
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

	publish: func [][
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

	pingreq: func [msg][
		; TODO: send pingresp?
	]

; ---- Context ends here

]




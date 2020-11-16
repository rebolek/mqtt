Red[]

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
	PINGRESP
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

connect-reason-codes: [
0
"Success"
"The Connection is accepted."

128
"Unspecified error"
"The Server does not wish to reveal the reason for the failure, or none of the other Reason Codes apply."

129
"Malformed Packet"
"Data within the CONNECT packet could not be correctly parsed."

130
"Protocol Error"
"Data in the CONNECT packet does not conform to this specification."

131
"Implementation specific error"
"The CONNECT is valid but is not accepted by this Server."

132
"Unsupported Protocol Version"
"The Server does not support the version of the MQTT protocol requested by the Client."

133
"Client Identifier not valid"
"The Client Identifier is a valid string but is not allowed by the Server."

134
"Bad User Name or Password"
"The Server does not accept the User Name or Password specified by the Client"

135
"Not authorized"
"The Client is not authorized to connect."

136
"Server unavailable"
"The MQTT Server is not available."

137
"Server busy"
"The Server is busy. Try again later."

138
"Banned"
"This Client has been banned by administrative action. Contact the server administrator."

140
"Bad authentication method"
"The authentication method is not supported or does not match the authentication method currently in use."

144
"Topic Name invalid"
"The Will Topic Name is not malformed, but is not accepted by this Server."

149
"Packet too large"
"The CONNECT packet exceeded the maximum permissible size."

151
"Quota exceeded"
"An implementation or administrative imposed limit has been exceeded."

153
"Payload format invalid"
"The Will Payload does not match the specified Payload Format Indicator."

154
"Retain not supported"
"The Server does not support retained messages, and Will Retain was set to 1."

155
"QoS not supported"
"The Server does not support the QoS set in Will QoS."

156
"Use another server"
"The Client should temporarily use another server."

157
"Server moved"
"The Client should permanently use another server."

159
"Connection rate exceeded"
"The connection rate limit has been exceeded."
]

suback-reason-codes: [
00h
"Granted QoS 0"
"The subscription is accepted and the maximum QoS sent will be QoS 0. This might be a lower QoS than was requested."

01h
"Granted QoS 1"
"The subscription is accepted and the maximum QoS sent will be QoS 1. This might be a lower QoS than was requested."

02h
"Granted QoS 2"
"The subscription is accepted and any received QoS will be sent to this subscription."
80h
"Unspecified error"
"The subscription is not accepted and the Server either does not wish to reveal the reason or none of the other Reason Codes apply."

83h
"Implementation specific error"
"The SUBSCRIBE is valid but the Server does not accept it."

87h
"Not authorized"
"The Client is not authorized to make this subscription."

8Fh
"Topic Filter invalid"
"The Topic Filter is correctly formed but is not allowed for this Client."

91h
"Packet Identifier in use"
"The specified Packet Identifier is already in use."

97h
"Quota exceeded"
"An implementation or administrative imposed limit has been exceeded."

9Eh
"Shared Subscriptions not supported"
"The Server does not support Shared Subscriptions for this Client."

A1h
"Subscription Identifiers not supported"
"The Server does not support Subscription Identifiers; the subscription is not accepted."

A2h
"Wildcard Subscriptions not supported"
"The Server does not support Wildcard Subscriptions; the subscription is not accepted."
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

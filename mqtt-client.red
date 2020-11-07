Red[
	Title: "MQTT client"
	Author: "Boleslav Březovský"
	Notes: {
Connection is ready.
next step:

- send SUBSCRIBE message
- receive SUBACK reply
- send PUBLISH message
	}
]

#include %mqtt-common.red

debug: :print

make-connection: func [][
	/local request: copy #{}
	append request make-conn-header []
	append request make-payload
	insert request enc-int length? request
	insert request #{10}
	request
]

;client: open tcp://192.168.54.102:1883
client: open tcp://127.0.0.1:1883
;client: open tcp://192.168.54.31:1833

b: make-connection

start: now/precise

client/awake: func [event /local port] [
	debug ["=== Client event:" event/type]
	port: event/port
	switch event/type [
		connect [insert port b]
		read [
			parse-message port/data
			; we received message and now we can send new one
			if mqtt/state = 'CONNACK [
				; send subscribe message
				; NOTE: this is just an example and must be user-configurable
				insert port make-subscribe-message "$SYS"
			]
		]
		wrote [copy port]
	]
]

run-client: does [

	if none? system/view [
		wait client
		print "1st Done"

		
	;	repeat n 120 [
	;		?? n
			open client
			wait client
	;	]
	]

]

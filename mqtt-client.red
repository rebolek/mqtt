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

make-connection: func [
	"Temporary function making CONNECT request in a very crude way"
][
	/local request: copy #{}
	append request make-conn-header []
	append request make-conn-payload
	insert request enc-int length? request
	insert request #{10}
	request
]

test-mqtt-awake: func [event /local port] [
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
				insert port make-subscribe-message ["$SYS" "a/b"]
			]
			if mqtt/state = 'SUBACK [
				; send publish message
				; NOTE: this is just an example and must be user-configurable
				insert port make-publish-message "a/b" "hello world"
			]
		]
		wrote [copy port]
	]
]

context [
	response: none
	client: none

	mqtt-awake: func [event /local port][
		port: event/port
		switch event/type [
			connect [
				data: ask "So what? "
				insert client send-mqtt 'PINGREQ none none
			]
			read [
				response: parse-message port/data
			;	close port
			]
			wrote [copy port]
		]
	]

	set 'send-mqtt funk [msg-type header payload][
		/local msg: make-message msg-type header payload
		insert client msg
	]

	set 'init-client func [][
		client: open tcp://127.0.0.1:1883
		client/awake: :mqtt-awake
	]

	run-client: does [
		client: open tcp://127.0.0.1:1883
		client/awake: :mqtt-awake
		b: make-connection
		insert client b
		wait client
	]
]

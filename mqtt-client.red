Red[
	Title: "MQTT client"
	Author: "Boleslav Březovský"
	Notes: {
Proper CONNECT message: #{101600044D515454050000000000097265646D7174747630}
	}
]

#include %mqtt-common.red
#include %mqtt-dialect.red

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

.: context [
	response: none
	client: none
	server: tcp://127.0.0.1:1883

	mqtt-awake: func [event /local port][
		port: event/port
		print ["xxxx" event/type "xxxx"]
		switch event/type [
			connect [
				insert client send-mqtt 'PINGREQ none none
			]
			read [
				response: parse-message port/data
				print "Closing port"
		;		close port
			]
			wrote [copy port]
		]
	]

	set 'send-mqtt funk [msg-type header payload][
		/local msg: probe make-message msg-type header payload
		insert client msg
		wait client
		print "afta waita"
		response
	]

	set 'init-client func [][
		client: open server
		client/awake: :mqtt-awake
	]

	set 'test-client has [msg] [
		client: open server
		client/awake: :mqtt-awake
		send-mqtt 'CONNECT none none
	]

	set 'mqtt-client funk [][
		client: open server
		client/awake: :mqtt-awake
		send-mqtt 'CONNECT none none
		until [
			data: ask "So what? "
			
			data = "q"
		]
		close client
	]
]

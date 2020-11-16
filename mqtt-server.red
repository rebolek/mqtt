Red[
	Title: "MQTT server"
	Author: "Boleslav Březovský"
]

#include %mqtt-common.red

clients: #()

; --

mqtt-awake: func [event /local port] [
	debug ["=== Client event:" event/type]
	port: event/port
	switch event/type [
		connect [insert port b]
		read [
			parse-message port/data
			; we received message and now we can send new one
			switch mqtt/state [
				PINGREQ [
					insert port make-message 'PINGRESP none none
				]
			]
		]
		wrote [copy port]
	]
]

run-server: does [
	server: open tcp://127.0.0.1:1883
	server/awake: :mqtt-awake
	wait client
]

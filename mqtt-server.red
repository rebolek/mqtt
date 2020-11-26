Red [
    title: "Basic TCP test server"
]

#include %mqtt-common.red

;debug: :print
debug: :comment

; --

sessions: #()

make-session: func [][
	put sessions mqtt-state/client-id context [
		; some session values
	]
]

update-session: funk [][
	either session: select sessions mqtt-state/client-id [
		; do some session update
	][
		make-session
	]
]

; --

process-data: func [port /local response] [
	;debug ["port data:" port/data]
	debug "process-data enter"
	unless empty? port/data [
		probe port/data
		parse-message port/data
		probe length? port/data
	;	print mold mqtt-state
		probe mqtt-state
		response: switch mqtt-state/type [
			CONNECT	[
				update-session
				make-message 'CONNACK none none
			]
			PINGREQ	[make-message 'PINGRESP none none]
			PUBLISH	[make-message 'PUBACK none none]
		]
		clear port/data
		insert port response
	]
	debug "process-data exit"
]

new-event: func [event] [
	debug ["=== Subport event:" event/type]
	switch event/type [
		read  [process-data event/port]
		wrote [copy event/port]
		close [probe "close client port" close event/port]
	]
]

new-client: func [port /local data] [
	debug ["=== New client ==="]
	port/awake: :new-event
	copy port
]

run-server: func [][

	clear sessions

	server: open tcp://:1883

	server/awake: func [event] [
		if event/type = 'accept [new-client event/port]
		false
	]

	print "MQTT server: waiting for client to connect"

	if none? system/view [
		wait server
		print "done"
		close server
	]
]

; --

run-server

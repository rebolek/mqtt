Red [
    title: "Basic TCP test server"
]

#include %mqtt-common.red

;debug: :print
debug: :comment

total: 0.0
count: 0

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
			CONNECT [make-message 'CONNACK none none]
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


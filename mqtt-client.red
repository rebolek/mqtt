Red[
	Title: "MQTT client"
	Author: "Boleslav Březovský"
]

#include %mqtt-common.red

debug: :print

make-connection: func [][
	request: copy #{}
	append request make-conn-header
	append request make-payload
	request
]


;client: open tcp://192.168.54.102:8123
client: open tcp://127.0.0.1:8123

b: make-connection

start: now/precise

client/awake: func [event /local port] [
    debug ["=== Client event:" event/type]
    port: event/port
    switch event/type [
        connect [insert port b]
        read [probe port/data close port]
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

puts "I'm going to run websockify."

set f [open "|websockify/run $::conf(websocket.ports) 127.0.0.1:[lindex $::conf(ports) 0]" r+]
puts "Started"
#fileevent $f readable { puts "WEBSOCKETS: [gets $f]" }

proc gethost {nick} {
	catch { return $::hosts([nick2id $nick]) }
	return "0.0.0.0"
}
proc hostmask {nick} {
	if { [string match "*.*" $nick] } { return $nick }
	return "${nick}!${nick}@[gethost $nick]"
}
proc proxyfromserver {server client host port thenick oldnick} {
	gets $server dat
	if { [eof $server] || [eof $client] } { close $server; close $client }
	if { $dat eq "" } return
	puts $dat
	set data [parseline $dat]
	switch -nocase -- [lindex $data 2] {
		INFO {
			if { [string match "*relaychat-1.1*" $dat] } {
				puts $client ":[lindex $data 1] 001 $thenick :Welcome to the relay chat network"
				puts $client ":[lindex $data 1] 004 $thenick :I'm running version relaychat-1.1"
				puts $client ":[lindex $data 1] 005 $thenick PREFIX=(ov)@+ CHANLIMIT=NONE CHANTYPES=# COMPLIANT=FALSE"
				puts $client ":[lindex $data 1] 375 $thenick :[lindex $data 1] message of the day!"
				return
			}
			if { [string match "*have*" $dat] } {
				puts $client ":[lindex $data 1] 376 $thenick :End of MOTD"
				puts $client ":[lindex $data 1] 251 $thenick :[lindex $data 3]"
			}
		}
		
		USERS {
			puts $client ":$::me 353 $thenick = [lindex $data 3] :[string map {* @} [lindex $data 4]]"
			puts $client ":$::me 366 $thenick [lindex $data 3] :End of /NAMES reply"
		}
		GLOBAL {
			puts $client ":[lindex $data 1] NOTICE $thenick :Global Message: [lindex $data 3]"
		}
		JOIN {
			puts $client ":[lindex $data 1]![lindex $data 1]@[gethost [lindex $data 1]] JOIN [lindex $data 3]"
		}
		PART {
			puts $client ":[hostmask [lindex $data 1]] PART [lindex $data 3] :Left"
		}
		QUIT {
			puts $client ":[hostmask [lindex $data 1]] QUIT :[lindex $data 3]"
		}
		BAN {
			if { [lindex $data 1] eq $::me } {
				puts $client ":$::me 367 $thenick [lindex $data 3] [lindex $data 4]"
			} else {
				puts $client ":[hostmask [lindex $data 1]] MODE [lindex $data 3] +b [lindex $data 4]"
			}
		}
		UNBAN {
			if { [lindex $data 1] eq $::me } {
				puts $client ":$::me 367 $thenick [lindex $data 3] [lindex $data 4]"
			} else {
				puts $client ":[hostmask [lindex $data 1]] MODE [lindex $data 3] -b [lindex $data 4]"
			}
		}
		TOPIC {
			if { [lindex $data 1] eq $::me } {
				puts $client ":$::me 332 $thenick [lindex $data 3] :[lindex $data 4]"
			} else {
				puts $client ":[hostmask [lindex $data 1]] TOPIC [lindex $data 3] :[lindex $data 4]"
			}
		}
		MESSAGE {
			puts $client ":[lindex $data 1]![lindex $data 1]@[gethost [lindex $data 1]] PRIVMSG [lindex $data 3] :[lindex $data 4]"
		}
		KICK {
			puts $client ":[hostmask [lindex $data 1]] KICK [lindex $data 3] [lindex $data 4] :Kicked"
		}
		MOTD {
			puts $client ":[lindex $data 1] 372 $thenick :- [lindex $data 3]"
		}
		ERROR {
			if { [string match "Closing link*" [lindex $data 3]] } {
			puts $client ":$::me ERROR $thenick :[lindex $data 3]"
			} else {
			if { [string match "*Nickname in use*" [lindex $data 3]] } {
			puts $client ":$::me NOTICE $thenick :Error: [lindex $data 3]"
			} else {
			puts $client ":$::me 433 $thenick * :Nickname in use"
			}
			}
		}
		NICK {
			puts $client ":[lindex $data 1]![lindex $data 1]@[gethost [lindex $data 3]] NICK :[lindex $data 3]"
		}
		PING {
			puts $server "PONG"
		}
		MOD {
			puts $client ":[hostmask [lindex $data 1]] MODE [lindex $data 3] +o [lindex $data 4]"
		}
		SERVERS {
			puts $client ":$::me 364 $thenick [lindex $data 3] [lindex $data 1] :1 A Remote Server"
		}
		DEMOD {
			puts $client ":[hostmask [lindex $data 1]] MODE [lindex $data 3] -o [lindex $data 4]"
		}
		ABOUT {
			puts $client ":$::me 311 $thenick [lindex $data 3] [lindex $data 3] [lindex $data 5] * :My local UID is [lindex $data 4]"
			puts $client ":$::me 318 $thenick [lindex $data 3] :End of /WHOIS reply"
		}
		LIST {
			puts $client ":$::me 322 $thenick [lindex $data 3] [cusers [lindex $data 3]] :$::topics([lindex $data 3])"
		}
	}
}

proc proxyfromclient {client server host port {curnick "*"}} {
	gets $client dat
	if { [eof $client] || [eof $server] } { close $client; close $server }
	if { $dat eq "" } return
	set data [parseline $dat]
	switch -- [lindex $data 0] {
		USER {}
		NICK {
			puts $server "NICK [lindex $data 1]"
			puts $server "SETHOST $host"
			fileevent $server readable [list proxyfromserver $server $client $host $port [lindex $data 1] abc]
		}
		JOIN {
			foreach c [split [lindex $data 1] ","] {
			puts $server "JOIN $c"
			puts $server "USERS $c"
			}
		}
		WALLOPS {
			puts $server "GLOBAL :[lindex $data 1]"
		}
		OPER {
			puts $server "MODLOGIN [lindex $data 1] [lindex $data 2]"
		}
		WHOIS {
			puts $server "WHOIS [lindex $data 1]"
		}
		LUSERS {
			puts $server "LUSERS"
		}
		LIST {
			puts $server "LIST"
		}
		PART {
			puts $server "PART [lindex $data 1]"
		}
		KICK {
			puts $server "KICK [lindex $data 1] [lindex $data 2]"
		}
		MODE {
			switch -- [lindex $data 2] {
				+o {
					puts $server "MOD [lindex $data 1] [lindex $data 3]"
				}
				-o {
					puts $server "DEMOD [lindex $data 1] [lindex $data 3]"
				}
				+b {
					if { [lindex $data 3] eq "" } {
					puts $server "BANS [lindex $data 1]"
					} else {
					puts $server "BAN [lindex $data 1] [lindex $data 3]"
					}
				}
				b {
					if { [lindex $data 3] eq "" } {
					puts $server "BANS [lindex $data 1]"
					} else {
					puts $server "BAN [lindex $data 1] [lindex $data 3]"
					}
				}
				-b {
					if { [lindex $data 3] eq "" } {
					puts $server "BANS [lindex $data 1]"
					} else {
					puts $server "UNBAN [lindex $data 1] [lindex $data 3]"
					}
				}
				
			}
		}
		TOPIC {
			puts $server "TOPIC [lindex $data 1] :[lindex $data 2]"
		}
		PING {
			puts $client ":$::me PONG :[lindex $data 2]"
		}
		CONNECT {
			puts $server "CONNECT [lindex $data 1] [lindex $data 2]"
		}
		QUIT {
			puts $server "QUIT :[lindex $data 2]"
		}
		PRIVMSG {
			puts $server "MESSAGE [lindex $data 1] :[lindex $data 2]"
		}
		KILL {
			puts $server "KILL [lindex $data 1] :[lindex $data 2]"
		}
		LINKS {
			puts $server "SERVERS"
		}
		REHASH {
			puts $server "REHASH"
		}
		RESTART {
			puts $server "RESTART"
		}
	}
}
proc ircproxy {sock host port} {
	fconfigure $sock -buffering line -translation auto
	set tgt [socket 127.0.0.1 [lindex $::conf(ports) 0]]
	fconfigure $tgt -buffering line -translation auto
	puts $sock ":$::me NOTICE * :This is a gateway to the relay chat network."
	fileevent $sock readable [list proxyfromclient $sock $tgt $host $port]
}
foreach p $::conf(ircgateway.ports) {
	socket -server ircproxy $p
}

puts "I've loaded the IRC Gateway Module"

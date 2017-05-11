# simple chat client
array set ::wins {status ""}
proc out {win text} {
	if { ! [info exists ::wins($win)] } { set ::wins($win) {} }
	lappend ::wins($win) $text
	if { $::curwin eq $win } { puts $text }
}
proc outall {text} {
	foreach c [array names ::wins] {
		out $c $text
	}
}
proc notify {tgtwin text} {
	if { $::curwin ne $tgtwin } {
		out $::curwin "-- Notification: $text --"
	}
}
set ::curwin status
proc handlein {cs} {
set line [gets $cs]
set linexx [list {*}[split [lindex [split [string map {" :" ^} $line] "^"] 0] " "] [join [lrange [split [string map {" :" ^} $line] "^"] 1 end] " :"]]
switch -nocase -regexp -- [lindex $linexx 2] {
	GLOBAL {
	out status "< Global Message from [lindex $linexx 1] > [lindex $linexx 3]"
	}
	MESSAGE {
	set pcx [lindex $linexx 1]
	if { [string index $pcx 0] eq "#" } {
		set pcx [linex $linexx 3]
	}
	out $pcx "([lindex $linexx 1]) [join [lrange $linexx 4 end]]"
	notify $pcx "You have a message from [lindex $linexx 1]"
	}
	USERS {
	out [lindex $linexx 3] "Users in [lindex $linexx 3]: [lindex $linexx 4]"
	}
	LIST {
	out status "Channel: [lindex $linexx 3]"
	}
	(MOTD|INFO) {
	out status "<server> [lindex $linexx 3]"
	}
	NICK {
	outall "-- [lindex $linexx 1] is now known as [lindex $linexx 3] --"
	}
	JOIN {
	out [lindex $linexx 3] "-- [lindex $linexx 1] has joined [lindex $linexx 3] --"
	}
	PART {
	out [lindex $linexx 3] "-- [lindex $linexx 1] has left [lindex $linexx 3] --"
	}
	KICK {
	out [lindex $linexx 3] "-- [lindex $linexx 4] was kicked from [lindex $linexx 3] by [lindex $linexx 1] --"
	}
	DEMOD {
	out [lindex $linexx 3] "-- [lindex $linexx 4] is no longer a moderator in [lindex $linexx 3] (thanks to [lindex $linexx 1]) --"
	}
	MOD {
	out [lindex $linexx 3] "-- [lindex $linexx 4] is now a moderator in [lindex $linexx 3] (thanks to [lindex $linexx 1]) --"
	}
	TOPIC {
	out [lindex $linexx 3] "-- the topic for [lindex $linexx 3] is: [lindex $linexx 4] (set by [lindex $linexx 1]) --"
	}
	default {
	out status "-- [join [lrange $linexx 1 end]] --"
	}
}
}
proc orc {a b} {
	if { $a eq "" } {
		return $b
	}
	return $a
}
proc handleout {cs} {
	gets stdin dat
	if { [string index $dat 0] == "/"} {
	set cmd [lindex $dat 0]
	switch -nocase [lindex $dat 0] {
		/lwin {
			set n 0
			foreach c [array names ::wins] {
			out $::curwin "Window ($n): $c"
			incr n
			}
		}
		/win {
			if { [info exists ::wins([lindex [array names ::wins] [lindex $dat 1]])] } {
			set ::curwin [lindex [array names ::wins] [lindex $dat 1]]
			out $::curwin "-- Switched to $::curwin --"
			foreach l $::wins($::curwin) {
			puts $l
			}
			}
		}
		/nick {
			puts $cs "NICK [lindex $dat 1]"
		}
		/join {
			puts $cs "JOIN [lindex $dat 1]"
			set ::curwin [string tolower [lindex $dat 1]]
		}
		/part {
			puts $cs "PART [lindex $dat 1]"
			unset ::wins([lindex $dat 1])
			set ::curwin status
		}
		/list {
		puts $cs "LIST"
		}
		/users {
			puts $cs "USERS [orc [lindex $dat 1] $::curwin]"
		}
		/topic {
			puts $cs "TOPIC [lindex $dat 1] :[lindex $dat 2]"
		}
		/demod {
			puts $cs "DEMOD [lindex $dat 1] [lindex $dat 2]"
		}
		/mod {
			puts $cs "MOD [lindex $dat 1] [lindex $dat 2]"
		}
		/kick {
			puts $cs "TOPIC [lindex $dat 1] [lindex $dat 2]"
		}
		/whois {
			puts $cs "WHOIS [lindex $dat 1]"
		}
		/nick {
			puts $cs "NICK [lindex $dat 1]"
		}
		/msg {
			puts $cs "MESSAGE [lindex $dat 1] :[lindex $dat 2]"
		}
		/modlogin {
			puts $cs "MODLOGIN [lindex $dat 1] [lindex $dat 2]"
		}
		/help {
			out status "Commands: /whois, /mod, /msg, /list, /kick, /demod, /join, /part, /lwin, /win, /modlogin"
		}

	}
	} else {
	if { $::curwin ne "status" } {
		puts $cs "MESSAGE [lindex [split $::curwin "@"] 0] :$dat"
	}
	}
}
set clientsock [socket [lindex $argv 0] [lindex $argv 1]]
fconfigure $clientsock -buffering line -translation auto
puts $clientsock "NICK [lindex $argv 2]"
fileevent stdin readable [list handleout $clientsock]
fileevent $clientsock readable [list handlein $clientsock ]

vwait eternity

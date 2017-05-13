 # CONFIG HERE
 
 set fname "chat.conf"
 if { [lindex $::argv 0] ne "" } {
	set fname [lindex $::argv 0]
 }
 puts "CONF $fname"
 proc _LoadConf {} {
 set o [open $::fname]
 while { ![eof $o] } {
 set x [gets $o]
 if { [string index $x 0] ne "#" } {
 array set ::conf [split $x "="]
 }
 }
 close $o
 set ::me $::conf(name)
 set ::ports $::conf(ports)
 set ::motd $::conf(motd)
 array set ::mods $::conf(mods)
}
 # END CONFIG
_LoadConf
 if {![info exists sock]} {
    set sock 1
    foreach p $::ports {
    set sock$p [socket -server connect $p]
    }
 }
 set usedtoks {}
 proc gettok {} {
   set _a #[clock clicks],[clock seconds]; lappend ::usedtoks $_a; return $_a
 }
proc uputs {sock text} {
	if { ! [info exists ::issock($sock)] } {
		puts $::realsocks($sock) "$text"
	} else {
		puts $sock $text
	}
}
 proc forcepong {} {
	foreach sock [array names ::issock] {
		catch { if { ([clock seconds] - $::lastpong($sock)) > 10 } {
			puts $sock "[gettok] $::me PING"
		}
		if { ([clock seconds] - $::lastpong($sock)) > 30 } {
			disconnect $sock {Ping timeout (40 seconds)}
		} }
	}
	after 5000 forcepong
 }
 proc connect {sock host port {isserver 0}} {
    fconfigure $sock -blocking 0 -buffering line
    fileevent $sock readable [list handleSocket $sock]
    set ::socks($sock) $sock
    set ::chans($sock) {}
    set ::issock($sock) 1
    set ::hosts($sock) $host
    set ::lastpong($sock) [clock seconds]
    if { $host in $::conf(deny) } {
	puts $sock "[gettok] $::me INFO :relaychat-1.1 You're banned from the Relay Chat Network!"
	disconnect $sock "You're banned"
	return
	}
    if { $isserver eq 1 } {
	puts $sock "[gettok] * NICK $::me"
	puts $sock "[gettok] * SERVER"
	puts $sock "[gettok] * BURST"
    }
    puts $sock "[gettok] $::me INFO :relaychat-1.1 Welcome to the Relay Chat Network!"
    set f [open $::motd]
    while { ![eof $f] } {
	puts $sock "[gettok] $::me MOTD :[gets $f]"
    }
    close $f
    puts $sock "[gettok] $::me INFO :You are now known as $sock"
    puts $sock "[gettok] $::me INFO :I have [llength [array names ::socks]] users on [llength [array names ::servers]] servers, [llength [array names ::issock]] local users."
    sendToAllServer "[gettok] $::me FAKENICK fake$sock[clock clicks] $sock $host"
}

 proc disconnect {sock args} {
    set nick $::socks($sock)
    sendTextAllFor $sock "[gettok] $nick QUIT :[join $args]"
    catch { puts $sock "[gettok] $::me ERROR :Closing Link: $::hosts($sock): [join $args]" }
    unset ::socks($sock)
    unset ::chans($sock)
    unset ::hosts($sock)
    catch { unset ::opers($sock) }
    if { [info exists ::servers($sock)] } {
	foreach {k v} [array get ::realsocks] {
		if { $v eq $sock } {
			disconnect $k "$nick $::me"
		}
	}
    }
    if { [info exists ::issock($sock) ] } {
	catch { unset ::servers($sock) }
    	unset ::issock($sock)
	fileevent $sock readable {}
	close $sock
    } else {
    sendToAllServer "[gettok] $::me KILL $nick :[join $args]"
	unset ::realsocks($sock)
   }
	
    #sendText "* $nick has left the chat: [join $args]"
 }
 # parseline really sucks like what does this even mean anymore
 proc parseline {line} {
    return [list {*}[split [lindex [split [string map {" :" ^} $line] "^"] 0] " "] [join [lrange [split [string map {" :" ^} $line] "^"] 1 end] " :"]]
 }
 proc handleSocket {sock} {
 catch {
    if { [chan pending input $sock] > 65536 } {
	disconnect $sock {Protocol violation (LINE_LENGTH > 65536)}
	return
    }
    gets $sock line
    set rsock $sock
    if {[eof $sock]} {
	fileevent $sock readable {}
	disconnect $sock {Connection reset by peer}
    }
    if {$line eq ""} return
    set linexx [list {*}[split [lindex [split [string map {" :" ^} $line] "^"] 0] " "] [join [lrange [split [string map {" :" ^} $line] "^"] 1 end] " :"]]


	if { [string index $line 0] == "#" } {
		set thetok [lindex $linexx 0]
		if { $thetok in $::usedtoks } return
		lappend ::usedtoks $thetok
	    puts "$sock: $line"
		set src [lindex $linexx 1]
		if { $src eq "*" } { set src $::socks($rsock) }
		if { [nick2id [lindex [split $src "@"] 0]] eq 0 } {
		#puts $sock "[gettok] $::me WARNING :Your connection could be closed due to a protocol violation [!]"
		if { [info exists ::servers($sock)] }  {
#		disconnect $sock "Protocol violation: user does not exist (Bug?): $src (with line $line)"
		} else {
		return
		}
		}
		set sock [nick2id $src]
		set linex [lrange $linexx 2 end]
	} else {
		set thetok [gettok]
	    puts "$sock: $line"
		set src "$::socks($sock)"
		set linex $linexx
	}

	switch -nocase [lindex $linex 0] {
		SERVER {
			puts $rsock "[gettok] * NICK $::me"
			puts $rsock "[gettok] * BURST"
			set ::servers($sock) $sock
		}
		REHASH {
			if { [info exists ::opers($sock)] } {
				_LoadConf
			}
		}
		BURST {
			set ::servers($sock) $sock
			puts "$::socks($sock) is now a server"
			foreach {k v} [array get ::socks] {
				puts $rsock "[gettok] $::me FAKENICK $::me-$k $v $::hosts($k)"
				foreach c $::chans($k) {
				puts $rsock "[gettok] $v JOIN $c"
				}
			}
			foreach c [array names ::cmods] {
				foreach l $::cmods($c) {
				puts $rsock "[gettok] $::me MOD $c $::socks($l)"
				}
				puts $rsock "[gettok] $::me TOPIC $c :$::topics($c)"
				puts $rsock "[gettok] $::me FLAGS $c + $::cflags($c)"
				foreach b $::cbans($c) {
				puts $rsock "[gettok] $::me BAN $c $b"
				}
			}
		}
		LIST {
			foreach {c} [array names ::topics] {
				if { "private" ni $::cflags($c) } {
				puts $rsock "[gettok] $::me LIST $c"
				}
			}
		}
		SETHOST {
			set ::hosts($sock) [lindex $linex 1]
		}
		FAKENICK {
			if { [nick2id [lindex $linex 2]] ne 0 && (![string match "*.*" [lindex $linex 2]])} {
			sendToAllServer "[gettok] $::me KILL $src :Nick collision"
			}
			set ::socks([lindex $linex 1]) [lindex $linex 2]
			set ::chans([lindex $linex 1]) {}
			set ::hosts([lindex $linex 1]) [lindex $linex 3]
			set ::realsocks([lindex $linex 1]) $rsock
			sendToAllServer "$thetok $src FAKENICK [lindex $linex 1] [lindex $linex 2] [lindex $linex 3]"
		}
		GLOBAL {
			puts "GLOBALING"
			sendText "$thetok $src GLOBAL :[lindex $linex 1]"
		}
		MODLOGIN {
			if { [info exists ::mods([lindex $linex 1])] && $::mods([lindex $linex 1]) ne [lindex $linex 2] } {
			puts $rsock "$thetok $::me ERROR :You've failed to authenticate as a Global Moderator!"
			} else {
			set ::opers($sock) "Global Moderator"
			sendText "$thetok $src GLOBAL :$::socks($sock)@$::hosts($sock) is now a global moderator"
			}
		}
		KILL {
			if { [nick2id [lindex $linex 1]] ne 0 && ( [info exists ::opers($sock)] || [info exists ::servers($rsock)] ) } {
			disconnect [nick2id [lindex $linex 1]] [lindex $linex 2]
			}
		}
		
		JOIN {
			if { [string tolower [lindex $linex 1]] in $::chans($sock) } return
			if { [string tolower [lindex $linex 1]] in $::conf(deny) } {
			puts $rsock "[gettok] $::me ERROR :This channel is not allowed to operate."
			return
			}
			if { ! [info exists ::topics([string tolower [lindex $linex 1]]) ] } {
				set ::topics([string tolower [lindex $linex 1]]) "No Topic Set"
				set ::cmods([string tolower [lindex $linex 1]]) {}
				if { ![info exists ::servers($rsock)] } {
				set ::cmods([string tolower [lindex $linex 1]]) $sock
				}
				set ::cbans([string tolower [lindex $linex 1]]) {}
				set ::cflags([string tolower [lindex $linex 1]]) {}
			}
			if { $::socks($sock) in $::cbans([string tolower [lindex $linex 1]]) || $::hosts($sock) in $::cbans([string tolower [lindex $linex 1]]) } {
			puts $rsock "[gettok] $::me ERROR :You're banned from this channel"
			return 
			}
			lappend ::chans($sock) [string tolower [lindex $linex 1]]
			sendTextToChan [string tolower [lindex $linex 1]] "$thetok $src JOIN [string tolower [lindex $linex 1]]"
			if { ! [info exists ::servers($rsock)] } { puts $rsock "[gettok] $::me TOPIC [string tolower [lindex $linex 1]] :$::topics([string tolower [lindex $linex 1]])" }
		}
		TOPIC {
			if { [lindex $linex 2] eq "" } {
			puts $rsock "[gettok] $::me TOPIC [string tolower [lindex $linex 1]] :$::topics([string tolower [lindex $linex 1]])"
			}
			if { ($sock in $::cmods([string tolower [lindex $linex 1]]) || [info exists ::servers($rsock)]) && [lindex $linex 2] ne "" || "anytopic" in $::cflags([string tolower [lindex $linex 1]])} {
			set ::topics([string tolower [lindex $linex 1]]) [lindex $linex 2]
			sendTextToChan [string tolower [lindex $linex 1]] "$thetok $src TOPIC [string tolower [lindex $linex 1]] :[lindex $linex 2]"
			}
		}
		PART {
			sendTextToChan [string tolower [lindex $linex 1]] "$thetok $src PART [string tolower [lindex $linex 1]]"
			set ::chans($sock) [lsearch -all -not -exact -inline $::chans($sock) [string tolower [lindex $linex 1]]]
			if { [cusers [string tolower [lindex $linex 1]]] == 0 } {
				unset ::topics([string tolower [lindex $linex 1]])
			}
		}
		KICK {
			if { [nick2id [lindex $linex 2]] eq 0 || [string tolower [lindex $linex 2]] eq [string tolower $::socks($sock)] } return
			if { $sock in $::cmods([string tolower [lindex $linex 1]]) || [info exists ::servers($rsock)]} {
		sendTextToChan [string tolower [lindex $linex 1]] "$thetok $src KICK [string tolower [lindex $linex 1]] [lindex $linex 2]"
			set ::chans([nick2id [lindex $linex 2]]) [lsearch -all -not -exact -inline $::chans([nick2id [lindex $linex 2]]) [string tolower [lindex $linex 1]]]
			} else {
				puts $rsock "$thetok $::me ERROR :You don't have permission to do that"
			}

		}
		BAN {
			if { !( $sock in $::cmods([string tolower [lindex $linex 1]]) || [info exists ::servers($rsock)] || [info exists ::opers($sock)])} { puts $rsock "$thetok $::me ERROR :You can't do that!"; return }
			sendTextToChan [string tolower [lindex $linex 1]] "$thetok $src BAN [string tolower [lindex $linex 1]] [lindex $linex 2]"
			lappend ::cbans([string tolower [lindex $linex 1]]) [lindex $linex 2]
		}
		UNBAN {
			if { !($sock in $::cmods([string tolower [lindex $linex 1]]) || [info exists ::servers($rsock)] || [info exists ::opers($sock)])} { puts $rsock "$thetok $::me ERROR :You can't do that!"; return }
			sendTextToChan [string tolower [lindex $linex 1]] "$thetok $src UNBAN [string tolower [lindex $linex 1]] [lindex $linex 2]"

			set ::cbans([string tolower [lindex $linex 1]]) [lsearch -not -all -exact -inline $::cbans([string tolower [lindex $linex 1]]) [lindex $linex 2]]
		}
		BANS {
			foreach b $::cbans([string tolower [lindex $linex 1]]) {
				puts $rsock "$thetok $::me BAN [string tolower [lindex $linex 1]] $b"
			}
		}
		PING {
			puts $rsock "PONG"
		}
		PONG {
			set ::lastpong($rsock) [clock seconds]
		}
		MOD {
			if { [nick2id [lindex $linex 2]] eq 0 } return
			if { $sock in $::cmods([string tolower [lindex $linex 1]]) || [info exists ::servers($rsock)] || [info exists ::opers($sock)]} {
				sendTextToChan [string tolower [lindex $linex 1]] "$thetok $src MOD [string tolower [lindex $linex 1]] [lindex $linex 2]"
		lappend ::cmods([string tolower [lindex $linex 1]]) [nick2id [lindex $linex 2]]
			} else {
				puts $rsock "$thetok $::me ERROR :You don't have permission to do that"
			}

		}
		DEMOD {
			if { [nick2id [lindex $linex 2]] eq 0 } return
			if { $sock in $::cmods([string tolower [lindex $linex 1]]) || [info exists ::servers($rsock)]} {
				sendTextToChan [string tolower [lindex $linex 1]] "$thetok $src DEMOD [string tolower [lindex $linex 1]] [lindex $linex 2]"
		set ::cmods([string tolower [lindex $linex 1]]) [lsearch -inline -all -not -exact $::cmods([string tolower [lindex $linex 1]]) [nick2id [lindex $linex 2]]]
			} else {
				puts $rsock "$thetok $::me ERROR :You don't have permission to do that"
			}
		}
		FLAGS {
			if { [lindex $linex 2] eq "" || [lindex $linex 3] eq "" } {
				puts $rsock "[gettok] $::me FLAGS [string tolower [lindex $linex 1]] + $::cflags([string tolower [lindex $linex 1]])"
				return
			} else if { $sock in $::cmods([string tolower [lindex $linex 1]]) || [info exists ::servers($rsock)]} {
				if { [lindex $linex 2] eq "-" } {
					sendTextToChan [string tolower [lindex $linex 1]] "$thetok $::me FLAGS [string tolower [lindex $linex 1]] - [join [lrange $linex 3 end]]"
					foreach c [lrange $linex 3 end] {
						set ::cflags([string tolower [lindex $linex 1]]) [lsearch -inline -all -not -exact $::cflags([string tolower [lindex $linex 1]]) $c]
					}
				} else {
					sendTextToChan [string tolower [lindex $linex 1]] "$thetok $::me FLAGS [string tolower [lindex $linex 1]] + [join [lrange $linex 3 end]]"
				foreach c [lrange $linex 3 end] {
					lappend ::cflags([string tolower [lindex $linex 1]]) [string tolower $c]
				}
				}
			} else {
				puts $rsock "[gettok] $::me ERROR :You don't have permission to modify channel flags"
			}
		}
		NICK {
			if { [lsearch -nocase $::conf(deny) [lindex $linex 1]] != -1 } {
				disconnect $sock "You're banned (Nickname)"
				return
			}
			if { [lsearch -nocase [array get ::socks] [lindex $linex 1]] != -1 } {
				puts $rsock "$thetok $::me ERROR :Nickname in use"
			} else {
				sendTextAllFor $sock "$thetok $src NICK [lindex $linex 1]"
				set ::socks($sock) [lindex $linex 1]
			}
		}
		CONNECT {
			if { [info exists ::opers($sock)] } {
			set host [lindex $linex 1]
			set port [lindex $linex 2]
	if { ! [catch { set sock [socket $host $port] }] } {
	connect $sock $host $port 1
	}
			sendText "$thetok $src GLOBAL :is connecting to remote server $host:$port"

			}
		}
		QUIT {
			disconnect $sock [lindex $linex 1]
		}
		WHOIS {
			if { [nick2id [lindex $linex 1]] eq 0 } return
			puts $rsock "$thetok $::me ABOUT [lindex $linex 1] [nick2id [lindex $linex 1]] $::hosts([nick2id [lindex $linex 1]]) :is my nickname, local uid, and hostname"
		}
		USERS {
	set chan [lindex $linex 1]
	set users {}
    foreach s [array names ::chans] {
        if { [string tolower $chan] in $::chans($s) } {
	set c ""
	if { $s in $::cmods([string tolower $chan]) } { set c "*" }
           lappend users $c$::socks($s)
        }
    }
		puts $rsock "$thetok $::me USERS [lindex $linex 1] :[join $users]"
		}
		MESSAGE {
			if { [nick2id [lindex $linex 1]] eq 0 } {
			sendTextToChan [string tolower [lindex $linex 1]] "$thetok $src MESSAGE [string tolower [lindex $linex 1]] :[lindex $linex 2]" $sock
			} else {
			uputs [nick2id [lindex $linex 1]] "$thetok $src MESSAGE [string tolower [lindex $linex 1]] :[lindex $linex 2]"
			}

		}
		ENCAP {
			if { [nick2id [lindex $linex 1]] eq 0 } {
			sendTextToChan [string tolower [lindex $linex 1]] "$thetok $src ENCAP [string tolower [lindex $linex 1]] :[lindex $linex 2]" $sock
			} else {
			uputs [nick2id [lindex $linex 1]] "$thetok $src ENCAP [string tolower [lindex $linex 1]] :[lindex $linex 2]"
			}

		}
		
	}
#        sendText "$::socks($sock): $line"
}
 }
 proc sendTextAllFor {sock text} {
   if { $sock != 0 } {
   catch { puts $sock $text }
   set done {}
   foreach c $::chans($sock) {
   #   sendTextToChan $c $text $sock
      foreach s [array names ::chans] {
	 if { [string tolower $c] in $::chans($s) && [info exists ::issock($s)] && $s ne $sock && $s ni $done } {
		lappend done $s
		puts $s $text
         }
      }
  }
  }
  sendToAllServer $text
 }
 proc nick2id {n} {
	foreach s [array names ::socks] { 
		if { [string tolower $::socks($s)] eq [string tolower $n] } {
			return $s
		}
	}
	return 0
 }
 proc sendToAllServer {text} {
	foreach s [array names ::servers] {
		puts "$s: $text"
		puts $s $text
	}
 }
 proc sendText {text} {
    foreach s [array names ::socks] {
	if { [info exists ::issock($s) ] } {
        puts $s $text
	}
    }
 }
 proc sendTextToChan {chan text {except ""}} {
    foreach s [array names ::chans] {
        if { [string tolower $chan] in $::chans($s) && [info exists ::issock($s)] && $s ne $except } {
           puts $s $text
        }
    }
    foreach s [array names ::servers] {
	puts $s $text
    }
 }

foreach {host port} $::conf(connects) {
	if { ! [catch { set sock [socket $host $port] }] } {
	connect $sock $host $port 1
	}

}
proc cusers {chan} {
	set users {}
    foreach s [array names ::chans] {
        if { [string tolower $chan] in $::chans($s) } {
	set c ""
	if { $s in $::cmods([string tolower $chan]) } { set c "*" }
           lappend users $c$::socks($s)
        }
    }
	return [llength $users]
}
foreach t $::conf(modules) {
	source $t
}
 after 1000 forcepong
 vwait forever

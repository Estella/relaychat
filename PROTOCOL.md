Hello there! This is about the protocol of Ronsor Relay Chat System, Version 1.1+

1. Client and Server Interactions and Protocol Standards.

## Client and Server Interactions and Protocol Standards

To begin a session, the client connects with or without TLS to the appropriate
port that a Ronsor Relay Chat System compatible server is listening on.

The standard port is 7654 and for TLS is 7657.

<< = messages from Server

>> = messages from Client

[message id] = unique id of the format #<random number>,<unix timestamp>. The
<unix timestamp> must be a real timestamp or clients and/or servers may react
unexpectedly. <random number> need not be especially random, in many cases
the C clock() function or tcl [clock clicks] function will provide a number
good enough for this.

[server name] = name of remote server

[server version] = version of remote server (usually relaychat-1.1)

[welcome message] = welcome message, usually "Welcome to the Relay Chat Network!"

On the reception of a connection, a server will send a response like:

    << [message id] [server name] INFO :[server version] [welcome message]
    -- then the MESSAGE OF THE DAY or MOTD should be sent line by line until it is done.
    << [message id] [server name] MOTD :[line]
    -- after the MESSAGE OF THE DAY, an INFO I_HAVE message should be sent like so
    << [message id] [server name] INFO :There are <users> users and 0 invisible on <servers> servers and I have <local users> local users.

Messages sent to a server should be in one of these three formats:

    >> [command] [param1 [param2 [...]] [:message (with spaces possible)]
    -- or
    >> [message id] * [command] [param1 [param2 [...]] [:message (with spaces possible)]
    -- or
    >> [message id] [source (either remote server or client)] [command] [param1 [param2 [...]] [:message (with spaces possible)]



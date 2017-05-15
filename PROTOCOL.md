Hello there! This is about the protocol of Ronsor Relay Chat System, Version 1.1+

1. Client and Server Interactions and Protocol Standards.
2. Server to Server Interactions
3. Commands
4. Conclusion

## Client and Server Interactions and Protocol Standards

To begin a session, the client connects with or without TLS to the appropriate
port that a Ronsor Relay Chat System compatible server is listening on.

The standard port is 7654 and for TLS is 7657.

| ~ | Definition |
|---|------------|
| << | messages from Server |
| >> | messages from Client |
| [message id] | unique id of the format #<random number>,<unix timestamp>. The <unix timestamp> must be a real timestamp or clients and/or servers may react unexpectedly. <random number> need not be especially random, in many cases the C clock() function or tcl [clock clicks] function will provide a number good enough for this. |
| [server name] | name of remote server |
| [server version] | version of remote server (usually relaychat-1.1) |
| [welcome message] | welcome message, usually "Welcome to the Relay Chat Network!" |

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

Clients should always use the first format.
While negotiating server-to-server protocol mode, the second form should be used.
If server-to-server protocol mode is activated or if you are sending to a client, the last form should be used.

Any other syntax is INVALID and should be met with an ERROR. If it is on a server-to-server
connection, you should disconnect the server with a PROTOCOL VIOLATION error.


## Server to Server Interaction

Connections from a client to a server are similar to server to server connection, however the connecting end should always begin with this:

    >> [message id] * NICK [server name]
    >> [message id] * SERVER
    >> [message id] * BURST

The server that receives these messages should respond with:

    >> [message id] * NICK [receiving server name]
    >> [message id] * BURST

### Commands

| Command | Parameters | Description | Server Response (<nl> means newline) |
|---------|------------|-------------|--------------------------------------|
| NICK | [desired nickname] | Set a nickname or server name | `[message id] [old nickname] NICK [new nickname]` |
| SERVER | none | Enable server mode, the receiving server should always respond as documented in **Server to Server Interaction** | see above |
| BURST | none | Respond with a series of FAKENICK, JOIN, MOD, TOPIC and other relevant commands to get the connecting server up to date on network state | not applicable |
| FAKENICK | [uid]* [nick]** [hostname] | Introduce a remote user into the network; Kill any nicknames that collide with another user. *UID is used for internal purposes and is random. **nicknames can be server names too; if it a server you should not KILL it during a nick collision. | fakenick message should be repeated to other servers on the network |
| JOIN | #[channel] | Join a channel; no ',' (commas) supported for multiple channels. Topic command must be sent to notify client of channel topic; Do not send topic to remote servers. First person to join gets moderator. | `[message id] [user] JOIN #[channel]` |
| MOD/DEMOD | #[channel] [user] | Grant or revoke moderator privileges to a user for a channel. | `[message id] [user] (DE)MOD #[channel] [other user]` |
| TOPIC | #[channel] [:topic text] | Set the channel topic; only available for moderators. | `[message id] [user] TOPIC #[channel] [:topic text]` |
| QUIT | [:message] | Disconnect a user; this is not sent to other servers in practice (KILL is used) but MUST work fine if done so. | `[message id] [user] QUIT [:message]` | 
| KILL | [target] [:message] | Forcibly disconnect a user or notify the rest of the network that a user on your server has disconnected. Global moderator/operator and servers only. | You must send a QUIT message to all local users on reception of this command. If the target user is on your server, send the proper disconnection messages. This varies from server to server. |
| MESSAGE | [target] [:message] | Send a message to a target, which may be either a user's nickname or a #[channel name]. | `[message id] [user] MESSAGE [target] [:message]` |
| USERS | #[channel] | List all users in a channel | `[message id] [server] USERS #[channel] :(*)user (*)nextuser` (a '*' is used at the beginning of a nickname to denote a moderator) |
| PART | #[channel] | Leave a channel | `[message id] [user] PART #[channel]` |
| WHOIS | [user] | Give nickname, local uid, and hostname of remote user | `[message id] [server] ABOUT [user nickname] [user local uid] [user hostname] :[optional informational message: e.g. "is my nickname, local uid, and hostname."]` |
| MODLOGIN | [name] [password] | Obtain global moderator privileges | GLOBAL message detailing who gained privileges |
| GLOBAL | [:message] | Send a global message | `[message id] [user or server] GLOBAL [:message]`

# xmpp: an experimental xmpp client

[XMPP](https://xmpp.org/) was created about the same era of IRC and MSN.
The concept of instant messenger at that time is quite different from now.
Fortunately, XMPP is flexible enough to adapt to different user habits.
Client is reponsible to decide its behavior instead of XMPP protocol.

For example, some instant messagers do not show online status now while some still do.
But generally people send messages regardless the online status of their friends.
Therefore, online status (presence) becomes less important now.

Original XMPP MUC (multi-user chat) depends on the presence of users in the chat room.
If they go offline, they leave the room.
Now people expect to stay in the group chat even when they go offline.
There are different approaches such as MUC Subscription or Pub/Sub.
The client (and server) needs to decide how to implement it.

This XMPP client is mainly for educational and experimental purpose.
It will not implement all functsions of XMPP, but could be a good start to fork.

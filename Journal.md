# Journal

## Development Setup

### Prosody (Server)

```
$> sudo apt install prosody
$> sudo vi /etc/prosody/conf.d/localhost.cfg.lua
$> sudo cat /etc/prosody/conf.d/localhost.cfg.lua
-- Section for localhost

c2s_require_encryption = false
s2s_require_encryption = false

-- This allows clients to connect to localhost. No harm in it.
VirtualHost "localhost"

$> sudo prosodyctl adduser alice@localhost
$> sudo systemctl restart prosody
```

Add cert for tls

```
$ mkcert localhost 192.168.1.100
$ sudo mv localhost.pem /etc/prosody/certs/localhost.crt
$ sudo mv localhost-key.pem /etc/prosody/certs/localhost.key
$ sudo chown prosody:prosody /etc/prosody/certs/localhost.crt
$ sudo chown prosody:prosody /etc/prosody/certs/localhost.key
$ sudo chmod 644 /etc/prosody/certs/localhost.crt
$ sudo chmod 600 /etc/prosody/certs/localhost.key
$ sudo ls -l /etc/prosody/certs
total 8
-rw-r--r-- 1 prosody prosody 1525 Sep  5 14:08 localhost.crt
-rw------- 1 prosody prosody 1708 Sep  5 14:08 localhost.key
```

```
$ sudo cat /etc/prosody/conf.d/localhost.cfg.lua
-- Section for localhost

c2s_require_encryption = true
s2s_require_encryption = true

-- muc
Component "conference.localhost" "muc"
    name = "localhost chatrooms server"
    modules_enabled = { "muc_mam" }
    restrict_room_creation = true

-- This allows clients to connect to localhost.
VirtualHost "localhost"
    ssl = {
        certificate = "/etc/prosody/certs/localhost.crt";
        key = "/etc/prosody/certs/localhost.key";
    }
```

### Profanity (Client)

```
$> sudo apt-get install profanity-light
$> profanity

/connect alice@localhost server ip_to_server tls disable
```

## libstrophe

### Memory Management

It uses reference count, thus, can free child node after it is added into parent node.

### tls

```
    if (init.environ_map.get("CA_FILE")) |value| {
        // add rootCA.pem from local server for development purpose
        st.xmpp_conn_set_cafile(conn, value.ptr);
    } else {
        // disable TLS
        flags = st.XMPP_CONN_FLAG_DISABLE_TLS;
    }
```

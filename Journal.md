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

### Profanity (Client)

```
$> sudo apt-get install profanity-light
$> profanity

/connect alice@localhost server ip_to_server tls disable
```

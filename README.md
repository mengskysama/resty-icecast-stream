# resty-icecast-stream

# Description

This library is a bridge from HTM5 MediaStream websocket data to icecast server

Note that nginx [stream module](https://nginx.org/en/docs/stream/ngx_stream_core_module.html) and [ngx_stream_lua_module](https://github.com/openresty/stream-lua-nginx-module) is required.

Tested on Openresty 1.9.15.1.

# Status

Experimental.

# Synopsis

```
server {
    listen 8080;
    location ~ /stream/(\d+) {
        set $icecast_host        8.8.8.8;
        set $icecast_port        80;
        set $icecast_path_tpl    /[stream_id].mp3;
        set $icecast_auth        xxxxxxxxxxxxxxxxx=;
        set $enable_valid_token  1;
        set $token_salt          val404nodefounddddfffggg;
        set $stream_id           $1;

        content_by_lua_block {
            local s = require "resty.icecaststream.server"
            s.run()
        }
    }
}
```

set `$icecast_host` 、`icecast_auth` and `icecast_port` to your icecast server, this server will PUT stream to icecast server from websocket .

If you want stream_id be safe set `enable_valid_token` to `1` and `token_salt` to `{random}` use token valid for each stream.

Eg. example config can `PUT` a stream from `ws://HOST/stream/11111?token={lower(md5(11111abc))}` to `http://8.8.8.8:80//11111.mp3`

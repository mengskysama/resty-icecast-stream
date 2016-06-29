-- subscriber implementaion
local ws_server = require "resty.websocket.server"
local util = require "resty.icecaststream.util"

local _M = util.new_tab(0, 10)
local mt = { __index = _M }

function _M.new(self, opts)
    local srvsock, err = ngx.socket.tcp()

    -- valid token
    if ngx.var.enable_token == '1' then
        local arg = ngx.req.get_uri_args()
        local token_ctx = opts.stream_id .. ngx.var.token_salt
        local real_token = ngx.md5(token_ctx)
        if arg['token'] ~= real_token then
            ngx.log(ngx.ERR, "[stream] token check faild token_ctx=", token_ctx ," md5=", real_token)
            return ngx.exit(403)
        end
    end

    if not srvsock then
        ngx.log(ngx.ERR, "[stream] can not init srvsock instance stream_id=", stream_id)
        return ngx.exit(500)
    end

    ngx.log(ngx.NOTICE, "[stream] initializing new stream stream_id=", stream_id)
    local ws, err = ws_server:new{
        timeout = 30000,
        max_payload_len = 65535,
    }
    if not ws then
        ngx.log(ngx.ERR, "[stream] failed to new websocket: ", err)
        return ngx.exit(500)
    end

    local _ = setmetatable({
        ws = ws,
        srvsock = srvsock,
        stream_id = opts.stream_id,
        closed = false,
        icecast_host = ngx.var.icecast_host,
        icecast_port = ngx.var.icecast_port,
        icecast_auth = ngx.var.icecast_auth,
        icecast_path_tpl = ngx.var.icecast_path_tpl
    }, mt)

    return _
end

local function _cleanup(self)
    self.closed = true
    if self.srvsock ~= nil then
        local ok, err = self.srvsock:close()
        if not ok then
            --
        end
    end
end

function _M.recv_loop(self)

    local ssock = self.srvsock
    local ws = self.ws
    local ws_recv_time = ngx.now()

    ssock:settimeout(15000)

    local ok, err = ssock:connect(self.icecast_host, self.icecast_port)
    if not ok then
        ngx.log(ngx.ERR, "[stream] connect to icecast server failed: ", err)
        _cleanup(self)
        return ngx.exit(500)
    end

    local path = ngx.re.gsub(self.icecast_path_tpl, "\\[stream_id\\]", self.stream_id)

    local req_header = "PUT " .. path .. " HTTP/1.1\r\nHost: " .. self.icecast_host .. "\r\nConnection: keep-alive\r\nContent-Type: audio/mp3\r\nAuthorization: Basic " .. self.icecast_auth .. "\r\n\r\n"
    local _, err = ssock:send(req_header)
    if err then
        ngx.log(ngx.ERR, "[stream] failed send header to icecast server: ", err)
        _cleanup(self)
        return ngx.exit(500)
    end

    while not self.closed do
        local data, typ, err = ws:recv_frame()
        if not data or err or typ == "close" then
            ngx.log(ngx.INFO, "[stream] closing ws connection stream_id=", self.stream_id, err)
            break
        end

        if typ == "ping" then
            -- send a pong frame back:
            local bytes, err = ws:send_pong(data)
            if not bytes then
                ngx.log(ngx.ERR, "[stream] ws failed to send pong: ", err)
                break
            end
        elseif typ == "pong" then
            -- just discard the incoming pong frame
        else
            ngx.log(ngx.INFO, "[stream] ws recv frame used time: ", ngx.now() - ws_recv_time)
            ws_recv_time = ngx.now()

            local ssock_recv_time = ngx.now()
            local _, err = ssock:send(data)
            ngx.log(ngx.INFO, "[stream] ssock send frame used time: ", ngx.now() - ssock_recv_time)

            if err then
                ngx.log(ngx.ERR, "[stream] ssock failed to send data: ", err)
                break
            end
        end
    end

    local bytes, err = ws:send_close(1000, "icecaststream say bye to you")
    _cleanup(self)

end

function _M.send_loop(self)

end

return _M

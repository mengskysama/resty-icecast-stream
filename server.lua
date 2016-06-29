local util = require "resty.icecaststream.util"
local stream = require "resty.icecaststream.stream"

local _M = util.new_tab(0, 2)

function _M.run()

    local s = stream:new({stream_id = ngx.var.stream_id})
    -- run stream, this will not exit until connection closed
    -- ngx.thread.spawn(s.send_loop, s)
    ngx.thread.spawn(s.recv_loop, s)
    -- connection closed here

end

return _M

local _M = { _VERSION = '0.01' }

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

_M.new_tab = new_tab

return _M

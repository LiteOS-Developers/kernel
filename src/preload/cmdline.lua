--#skip 13
--[[
    Copyright (C) 2023 thegame4craft

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]--
k.cmdline = {}
do
    local args = table.pack(...)
    local segs = {}
    for s in string.gmatch(args[1], "([^,]+)") do
        segs[#segs+1] = s
    end
    for _, s in ipairs(segs) do
        local m = string.gmatch(s, "([^=]+)")
        local key = m()
        local val = m()

        if val == "true" then val = true
        elseif val == "false" then val = false
        else val = tonumber(val) or val end
        k.cmdline[key] = val
    end
end
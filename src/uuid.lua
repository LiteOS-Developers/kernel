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
k.printk(k.L_INFO, "uuid")
--#define UUID


k.uuid = {}

function tohex(str)
    return (str:gsub('.', function (c)
        return string.lower(string.format('%02X', string.byte(c)))
    end))
end
local function zFill(str, n)
    while string.len(str) < n do
        str = "0" .. str
    end
    return str
end

k.uuid.next = function()
    local sets = {4, 2, 2, 2, 6}
    local result = ""
    local pos = 0
    for _,set in ipairs(sets) do
        if result:len() > 0 then
          result = result .. "-"
        end
        for _ = 1,set do
            local byte = math.random(0, 255)
            result = result .. zFill(string.format("%x", byte), 2)
        end
    end
    return result
end
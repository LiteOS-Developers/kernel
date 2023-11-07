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

k.printk(k.L_INFO, "lib/getpass")

k.getpass = function()
    local line = ""

    local x, y = k.cursor:getX(), k.cursor:getY()
    while true do
        local _, addr, char, code, ply = k.event.pull("key_down")
        local chr = utf8.char(char)
        if chr == "\r" then
            k.setText(x, y, " ")
            k.printf("%s\n", string.rep("*", line:len()))
            break
        elseif chr == "\b" then
            line = line:sub(1, -2)
        elseif chr == "\t" then
            line = line .. "    "
        else
            line = line .. chr
        end
        k.setText(x, y, string.rep("*", line:len()))
    end
    return line
end
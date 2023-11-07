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

k.printk(k.L_INFO, "user/init")

-- local result, e = k.parse_ansi("")
-- local result, e = k.parse_ansi("Normal Hello World\n without Ansi\27[1;32;41mhello\n\27[1;36mWorld\n")
-- if not result then 
--     k.printf("%s\n", e)
--     k.hlt()
-- end
-- for part, comp in pairs(result) do
--     k.printf("%d %s\n", part, dump(comp))
-- end
-- k.hlt()
k.exec("/sbin/init.lua", nil, false)
k.printk(k.L_INFO, "Kernel successfully loaded")


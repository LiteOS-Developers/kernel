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

k.printk(k.L_INFO, "scheduler/permission")

k.umask = function(v)
    local result = 0
    local root = v:sub(1, 3)
    local group = v:sub(4,6)
    local others = v:sub(7,9)
    result = result | (root:sub(1) == "r" and 256 or 0) 
    result = result | (root:sub(2) == "w" and 128 or 0) 
    result = result | (root:sub(3) == "x" and 64 or 0) 

    result = result | (group:sub(1) == "r" and 32 or 0) 
    result = result | (group:sub(2) == "w" and 16 or 0) 
    result = result | (group:sub(3) == "x" and 8 or 0)

    result = result | (others:sub(1) == "r" and 4 or 0) 
    result = result | (others:sub(2) == "w" and 2 or 0) 
    result = result | (others:sub(3) == "x" and 1 or 0) 
    return result
end

k.umask_to_str = function(v)
    local result = (v & k.perm.FS_DIR ~= 0 and "d" or "f") -- TODO: needs improvement for socket and more
    result = result .. (v & 256 ~= 0 and "r" or '-') 
    result = result .. (v & 128 ~= 0 and "w" or "-") 
    result = result .. (v & 64 ~= 0  and "x" or "-") 

    result = result .. (v & 32 ~= 0 and "r" or '-') 
    result = result .. (v & 16 ~= 0 and "w" or "-") 
    result = result .. (v & 8 ~= 0  and "x" or "-") 

    result = result .. (v & 4 ~= 0 and "r" or '-') 
    result = result .. (v & 2 ~= 0 and "w" or "-") 
    result = result .. (v & 1 ~= 0 and "x" or "-") 
    return result
end

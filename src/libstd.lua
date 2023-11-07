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


function deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
            end
            t = deepcopy(getmetatable(orig), copies)
            if type(t) == "table" or type(t) == "nil" then
                setmetatable(copy, t)
            end
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

table.keys = function(t)
    checkArg(1, t, "table")
    local r = {}
    for k, v in pairs(t) do
        _G.table.insert(r, k)
    end
    return r
end

table.forEach = function(tbl, f)
    checkArg(1, tbl, "table")
    checkArg(2, f, "function")
    local res = {}

    for _, value in pairs(tbl) do
        local r = f(_, value)
        if r then res[_] = r end 
    end
    if #res > 0 then return res end
end

function table.merge(p, s)
    for key, value in pairs(s) do
        p[key] = value
    end
    return p
end
table.contains = function(t, val)
    for _, v in pairs(t) do
        if v == val then return true end
    end
    return false
end

function split(inputstr, sep)
    checkArg(1, inputstr, "string")
    checkArg(2, sep, "string")
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end
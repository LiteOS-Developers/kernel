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

k.printk(k.L_INFO, "lib/ansi")

function k.parse_ansi_line(v)
    checkArg(1, v, "string")
    local parts = {}
    local current_part = {}
    local i = 1
    while i <= v:len() do
        if v:sub(i,i) == "\27" then
            parts[#parts + 1] = deepcopy(current_part)
            current_part = {}
            i = i + 1
            if v:sub(i,i) == "[" then
                i = i + 1
                char = v:sub(i,i)
                if char == "1" then
                    if v:sub(i+1, i+1) ~= ";" then
                        return nil, "Missing ';' at position " .. tostring(i + 1)
                    end
                    i = i + 1
                    while true do
                        i = i + 1
                        char = v:sub(i,i)
                        if char == "m" then
                            i = i + 1
                            break
                        elseif char == "3" then -- foreground
                            i = i + 1
                            char = v:sub(i,i)
                            i = i + 1
                            current_part.foreground = tonumber(char)                            
                        elseif char == "4" then -- background
                            i = i + 1
                            char = v:sub(i,i)
                            i = i + 1
                            current_part.background = tonumber(char) 
                        elseif char == "0" then -- reset
                            
                        end

                        if v:sub(i,i) ~= ";" and v:sub(i+1, i+1) ~= "m" and v:sub(i,i) ~= "m" then
                            return nil, "Missing ';' at position " .. tostring(i)
                        elseif v:sub(i,i) == "m" then
                            i = i + 1
                            break
                        end
                    end
                elseif char == "m" then
                    current_part.foreground = 7
                    current_part.background = 0
                    i = i + 1
                end
            end
        else
            current_part.content = (current_part.content or "") .. v:sub(i,i)
            i = i + 1
        end
    end
    parts[#parts + 1] = deepcopy(current_part)
    -- if #table.keys(parts[1]) == 0 then 
    --     table.remove(parts, 1)
    -- end
    return parts
end
function k.parse_ansi(v)
    checkArg(1, v, "string")
    lines = split(v, "\n") 
    output = {}
    for idx, line in ipairs(lines) do
        if line:len() ~= 0 then
            output[idx], e = k.parse_ansi_line(line)
            if output[idx] ~= nil then
                local length = #output[idx]
                if idx <= #lines - 1 then -- there are lines left
                    output[idx][length].content = (output[idx][length].content or "") .. "\n"
                elseif idx == #lines and v:sub(-1,-1) == "\n" then -- we came to the last line of that string
                    output[idx][length].content = (output[idx][length].content or "") .. "\n"
                end
            else
                return nil, e
            end
        end
    end
    
    return output
end
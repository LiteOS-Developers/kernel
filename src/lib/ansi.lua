k.printk(k.L_INFO, "lib/ansi")

local decPos = {x = 1, y = 1}

function k.store_dec(x, y)
    decPos = {x = x, y = y}
end

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
            if v:sub(i,i+1) == " 7" then
                i = i + 2
                current_part = {
                    cmd = "store_dec",
                    func = k.store_dec
                }
                -- decPos = {x = x, y = y}
            elseif v:sub(i,i+1) == " 8" then
                i = i + 2
                -- k.printf("restore\n\n%s", dump(decPos))
                current_part = {
                    line = decPos.x,
                    column = decPos.y
                }
            elseif v:sub(i, i+2) == "[2J" then
                i = i + 3
                current_part = {cmd="clear_screen"}
            --[[elseif v:sub(i,i) == "[" and v:sub(i+1,i+1):match("[0-9]") then
                i = i + 1
                local line = ""
                local char = v:sub(i,i)
                while char:match("[0-9]") do
                    line = line .. char
                    i = i + 1
                    char = v:sub(i,i)
                end
                if char ~= ";" then return nil, string.format("Missing ';' in ANSI. Location %d", i) end
                i = i + 1
                local column = ""
                local char = v:sub(i,i)
                while char:match("[0-9]") do
                    column = column .. char
                    i = i + 1
                    char = v:sub(i,i)
                end
                if v:sub(i,i) ~= "H" then return nil, string.format("Missing 'H' in ANSI. Location %d", i) end
                i = i + 1
                local line = tonumber(line)
                local column = tonumber(column)
                current_part = {
                    line = line,
                    column = column
                }
            ]]

            elseif v:sub(i,i) == "[" then
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
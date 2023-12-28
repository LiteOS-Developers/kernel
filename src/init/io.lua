--#ifdef LIB_BUFFER
k.printk(k.L_INFO, "init/io")

k.io = {}

k.readfile = function(path)
    local data = ""
    local chk
    -- error(dump(path))
    local file, e = k.open(path, "r")

    if not file then
        return nil, e
    end
    repeat
        chk = k.read(file, math.huge)
        data = data .. (chk or "")
    until not chk
    k.close(file)
    return data
end

k.io.stdout = k.buffer.new("w", {
    write = function(self, buf)
        k.printf(buf .. "\n")
    end
})
k.io.stdout:setvbuf("no")
k.io.stderr = k.buffer.new("w", {
    write = function(self, buf)
        local old, _ = k.gpu.setForeground(0xF00000)
        k.printf(buf .. "\n")
        k.gpu.setForeground(old, _)
    end
})
k.io.stderr:setvbuf("no")

k.io.stdin = k.buffer.new("r", {
    read = function(self, count)
        local line = ""
        local x, y = k.cursor:getX(), k.cursor:getY()
        if y + 1 > k.cursor.height then
            y = k.cursor.height
        end
        while true do
            local _, addr, char, code, ply = k.event.pull("key_down")
            if char == 0 and (code == 42 or code == 54) then -- shift (r and l)
                goto continue
            elseif char == 0 and (code == 29 or code == 184 or code == 157) then -- strg or Alt Gr
                goto continue
            elseif char == 0 and code == 56 then -- alt
                goto continue
            elseif char == 0 and code == 219 then -- super key (windows key)
                goto continue
            elseif char == 0 and code == 58 then -- caps lock 
                goto continue
            elseif char == 0 and code == 221 then -- context menu
                goto continue
            elseif char == 0 and code == 69 then -- num
                goto continue
            elseif char == 0 and (code == 210 or code == 211 or code == 197) then -- num, ins, entf (remove key), break
                goto continue
            elseif char == 0 and (code == 200 or code == 203 or code == 205 or code == 208) then -- arrow keys
                goto continue
            elseif char == 0 and (code == 209 or code == 201) then -- page up and down
                goto continue
            elseif char == 0 and code >= 59 and code <= 68 then -- f1 to f10
                goto continue
            elseif char == 0 and (code == 87 or code == 88) then -- page up and down
                goto continue
            end

            local chr = utf8.char(char)
            if chr == "\r" then
                k.setText(x, y, " ")
                k.cursor:move(x, y)
                k.printf("%s\n", line)
                break
            elseif chr == "\b" then
                line = line:sub(1, -2)
            elseif chr == "\t" then
                line = line .. "    "
            else
                line = line .. chr
            end
            k.setText(x, y, line)
            ::continue::
        end
        return line
    end
})
k.io.stdin:setvbuf("no")

--#endif 
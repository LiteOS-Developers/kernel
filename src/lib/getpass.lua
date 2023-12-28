
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
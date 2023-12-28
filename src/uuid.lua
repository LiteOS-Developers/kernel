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
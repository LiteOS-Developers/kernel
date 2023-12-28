k.cmdline = {}
do
    local args = table.pack(...)
    local segs = {}
    for s in string.gmatch(args[1], "([^,]+)") do
        segs[#segs+1] = s
    end
    for _, s in ipairs(segs) do
        local m = string.gmatch(s, "([^=]+)")
        local key = m()
        local val = m()

        if val == "true" then val = true
        elseif val == "false" then val = false
        else val = tonumber(val) or val end
        k.cmdline[key] = val
    end
end
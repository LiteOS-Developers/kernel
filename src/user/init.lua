

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


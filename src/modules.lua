k.printk(k.L_INFO, "modules")

--#ifndef ROMFS
--#error ROMFS IS NOT LOADED! PLEASE CHECK THAT
--#endif

local moduleBase = MODULE_BASE

function k.load_module(mod)
    checkArg(1, mod, "string")
    local rom, e = k.romfs.open(moduleBase .. "/" .. mod)
    if not rom then 
        error(e)
        k.hlt()
    end
    k.printk(k.L_INFO, "Read Module %s", mod)
    env = _G
    env.k = k
    local result, err = load(rom:content("main.lua"), "=[module " .. mod .. "]", "t", env)
    if not result then
        error(err)
        k.hlt()
    end
    return result()
end
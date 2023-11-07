k.devfs.types = {}

function k.devfs.register_device_type(major, minor, type_,  callable)
    checkArg(1, major, "number")
    checkArg(2, minor, "number")
    checkArg(3, type_, "string")
    checkArg(4, callable, "function")
    
    local index = string.format("%s%d.%d", type_:sub(1,1), major, minor)
    if k.devfs.types[index] then
        k.panic("attempted to double-register devfs-type " .. type_)
    end
    k.devfs.types[index] = callable
end

--#include "drivers/fs/devfs_types/gpu.lua"
--#include "drivers/fs/devfs_types/tty.lua"

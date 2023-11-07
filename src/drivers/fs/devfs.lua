--#ifndef UUID
--#error UUID is not loaded
--#endif
--#define DRV_DEVFS
k.printk(k.L_INFO, "drivers/fs/devfs")
k.devfs = {}

do
    local provider = {}
    provider.address = "devfs"
    local devices = {}
    local handles = {}

    local dev_api = {}

    function k.devfs.register_device(path, device)
        checkArg(1, path, "string")
        checkArg(2, device, "table")
    
        local segments = k.split_path(path)
        if #segments > 1 then
            error("cannot register device in subdirectory '"..path.."' of devfs", 2)
        end
    
        devices[path] = device
    
        if path:sub(1,1) ~= "/" then path = "/" .. path end
        k.printk(k.L_INFO, "devfs: registered device at %s", path)
    end

    function k.devfs.unregister_device(path)
        checkArg(1, path, "string")
    
        local segments = k.split_path(path)
        if #segments > 1 then
            error("cannot unregister device in subdirectory '"..path.."' of devfs", 2)
        end
    
        devices[path] = nil
    
        if path:sub(1,1) ~= "/" then path = "/" .. path end
        k.printk(k.L_INFO, "devfs: unregistered device at %s", path)
    end

    local function path_to_node(path)
        local segments = k.split_path(path)
    
        if path == "/" or path == "" then
            return devices[path]
        end
    
        if not devices["/" .. segments[1]] then
            return nil, k.errno.ENOENT
        else
            return devices["/" .. segments[1]], table.concat(segments, "/", 2, segments.n)
        end
    end

    k.devfs.lookup = path_to_node

    k.devfs.register_device("/", { 
        list = function(_)
            local devs = {}
            for key, path in pairs(devices) do
                --[[local segs = split(k, "/")
                if #segs >= 2 and segs[1]:len() > 0 then goto continue end
                if k ~= "/" then devs[#devs+1] = k end
                ::continue::]]
                devs[#devs+1] = k.split_path(key)[1]
            end
            return devs
        end,
    
        stat = function()
            return { 
                dev = -1, ino = -1, mode = 16877, nlink = 1,
                uid = 0, gid = 0, rdev = -1, size = 0, blksize = 2048,
                atime = 0, ctime = 0, mtime = 0
            }
        end
    })

    function provider:stat(path, ...)
        k.debug(string.format("devfs#stat '%s' %s\n", path, dump(devices)))
        if devices[path] ~= nil and devices[path].stat then return devices[path].stat() end
        if devices[path] == nil then return nil, k.errno.ENOENT end
        return { 
            dev = -1, ino = -1, mode = 33234, nlink = 1,
            uid = 0, gid = 0, rdev = -1, size = 0, blksize = 2048,
            atime = 0, ctime = 0, mtime = 0
        }
    end

    function provider:du()
        return {
            free = 1024,
            used = 0,
            label="devfs"
        }
    end

    function provider:ioctl(fd, call, ...)
        checkArg(1, fd, "number", "table")
        checkArg(2, call, "string")
        local handle = handles[fd]
        if not handle then return nil, k.errno.EBADF end
        if handle.closed then
            return nil, k.errno.EBADFD
        end
        local calls = devices[handle.device]
        if not calls[call] then return nil, k.errno.ENOSYS end
        return table.unpack(table.pack(calls[call](...)))
    end

    function provider:close(fd)
        checkArg(1, fd, "number", "table")
        local handle = handles[fd]
        if not handle then return nil, k.errno.EBADF end
        if handle.closed then return nil, k.errno.EBADFD end
        handle.closed = true
    end

    function provider:open(path, mode)
        checkArg(1, path, "string")
        checkArg(2, mode, "string", "nil")
        local fd
        repeat
            fd = math.random(0, 10000000)
        until not handles[fd]
        handles[fd] = {device = path}
        k.debug(string.format("devfs open %s\n", path))
        return fd
    end

    function provider:exists(path)
        k.debug(string.format("provider:exists %s %s %s\n", path, dump({k.split_path(path)}), dump(devices)))
        checkArg(1, path, "string")
        
        return not not path_to_node(path)
    end

    local function autocall(calling, pathorfd, ...)
        checkArg(1, pathorfd, "string", "table")
    
        if type(pathorfd) == "string" then
            local device, path = path_to_node(pathorfd)
        
            if not device then return nil, k.errno.ENOENT end

            local result, err 
            if not device[calling] and not provider[calling] then
                return nil, k.errno.ENOSYS
            elseif not device[calling] and provider[calling] then
                result, err = provider[calling](provider, pathorfd, ...)
            elseif device[calling] then
                result, err = device[calling](device, path, ...)
            end
        
            if not result then return nil, err end
            if result and calling == "open" then
                return { node = device, fd = result }
        
            else
                return result, err
            end
    
        else
            if not (pathorfd.node and pathorfd.fd) then
                return nil, k.errno.EBADF
            end
        
            local device, fd = pathorfd.node, pathorfd.fd
            if not device[calling] then                
                return nil, k.errno.ENOSYS
            end
        
            local result, err
            if calling == "ioctl" and not device.is_dev then
                result, err = device[calling](fd, ...)
            else
                result, err = device[calling](device, fd, ...)
            end
            return result, err
        end
    end
    
    provider.default_mode = "none"

--#include "drivers/fs/devfs_types/main.lua"

    setmetatable(provider, {__index = function(_, key)
        if key ~= "ioctl" then
            return function(_, ...)
                return autocall(key, ...)
            end
        else
            return function(...)
                return autocall(key, ...)
            end
        end
    end})

    k.register_fstype("devfs", function(x)
        return x == "devfs" and provider
    end)
    
end


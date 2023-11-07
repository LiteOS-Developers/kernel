local ttyprovider = {
    dir = "/",
    env = {
        PATH = "/bin:/usr/bin"
    },
}


local function exec(cmd, args)
    checkArg(1, cmd, "string")
    checkArg(2, args, "table", "nil")

    if not k.syscalls.exists(cmd) then
        return -1, k.errno.ENOENT
    elseif k.syscalls.isDirectory(cmd) then
        return -1, k.errno.EISDIR
    end
    local pid, errno = k.syscalls.fork(function()
        local _, errno = k.syscalls.execve("/bin/sh.lua", {
            "-c",
            cmd,
            "--",
            table.unpack(args or {})
        })
        if not _ then
            k.printk(k.L_EMERG, "tty: execve failed: %d\n", tonumber(errno or -1))
            k.syscalls.exit(1)
        end
    end)
    coroutine.yield(0)

    if not pid then
        k.printk(k.L_EMERG, "tty: fork failed: %d\n", errno)
        return nil, errno
    else
        return pid
    end
end

ttyprovider.chdir = function(dir)
    checkArg(1, dir, "string", "nil")
    if type(dir) == "nil" then return ttyprovider.dir end
    ttyprovider.dir = dir
    return dir
end

ttyprovider.resolve = function(cmd)
    checkArg(1, cmd, "string")
    if cmd:sub(1,2) == "./" then
        cwd = ttyprovider.dir
        if cwd:sub(-1,-1) ~= "/" then
            cwd = cwd .. "/"
        end
        return cwd .. cmd
    elseif cmd:sub(1,1) == "/" then
        return cmd
    end
    if string.find(cmd, "/") ~= nil then
        return nil
    end
    for _, p in ipairs(split(ttyprovider.env.PATH, ":")) do
        if p:sub(-1,-1) ~= "/" then p = p .. "/" end
        if k.syscalls.exists(p .. cmd .. ".lua") then
            if not k.syscalls.isDirectory(p .. cmd .. ".lua") then
                return p .. cmd .. ".lua"
            end
        end
    end
    return nil
end

ttyprovider.execute = function(cmd, args)
    checkArg(1, cmd, "string")
    checkArg(2, args, "table", "nil")
    local pid, errno = exec(cmd, args)
    return pid, errno
end

local mt = {
    __index = ttyprovider
}

for i=0,15 do
    k.devfs.register_device_type(8, i, "c", function(...)
        return deepcopy(ttyprovider)
    end)
end
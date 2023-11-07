--#ifndef UUID
--#error UUID is not loaded
--#endif
--#define DRV_PROCFS

k.printk(k.L_INFO, "drivers/fs/procfs")
local provider = {
    address = "procfs",
    files = {}
}

provider.files.meminfo = {data = function()
    local avgfree = 0
    for i=1, 10, 1 do avgfree = avgfree + computer.freeMemory() end
    avgfree = avgfree / 10

    local total, free = math.floor(computer.totalMemory() / 1024), math.floor(avgfree / 1024)
    local used = total - free
    return string.format("MemTotal: %d kB\nMemUsed: %d kB\nMemAvailable: %d kB\n", total, used, free)
end}


provider.files.filesystems = { data = function()
    local result = {}

    for fs, rec in pairs(k.fstypes) do
        if rec(fs) then fs = fs .. " (nodev)" end
        result[#result+1] = fs
    end

    return table.concat(result, "\n") .. "\n"
end}

provider.files.uptime = { data = function()
    return tostring(computer.uptime()) .. "\n"
end }

provider.files.mounts = { data = function()
    local result = {}
    for path, node in pairs(k.mounts()) do
        result[#result+1] = string.format("%s %s %s", node.address, path, node.mountType)
    end

    return table.concat(result, "\n") .. "\n"
end }

provider.files["/"] = {
    stat = function()
        return { 
            dev = -1, ino = -1, mode = 16877, nlink = 1,
            uid = 0, gid = 0, rdev = -1, size = 0, blksize = 2048,
            atime = 0, ctime = 0, mtime = 0
        }
    end,
    list = function()
        local files = provider.files
        files["/"] = nil
        return table.keys(files)
    end
}

--#include "drivers/fs/procfs_event.lua"

local function path_to_node(path, narrow)
    local segments = k.split_path(path)

    if #segments == 0 then
        local flist = {}

        for _, pid in pairs(k.get_pids()) do
            flist[#flist+1] = pid
        end

        for k in pairs(files) do
            flist[#flist+1] = k
        end

        return flist
    end

    if segments[1] == "self" then
        segments[1] = k.current_process().pid
    end

    -- disallow reading greater than /N/fds/N for security
    if segments[2] == "fds" then
        if #segments > 3 then
            return nil, k.errno.ENOENT
        elseif #segments == 3 then
            if narrow == 1 then return nil, k.errno.ENOTDIR end
        end
    end

    if provider.files[segments[1]] then
        if narrow == 1 then return nil, k.errno.ENOTDIR end

        if #segments > 1 then return nil, k.errno.ENOENT end
        return provider.files[segments[1]], nil, true
    elseif tonumber(segments[1]) then
      local proc = k.get_process(tonumber(segments[1]))
      local field = proc

      for i=2, #segments, 1 do
            field = field[tonumber(segments[i]) or segments[i]]
            if field == nil then return nil, k.errno.ENOENT end
      end

      return field, proc
    end

    return nil, k.errno.ENOENT
end

local function to_fd(dat)
    dat = tostring(dat)
    local idx = 0

    return k.fd_from_rwf(function(_, n)
        local nidx = math.min(#dat + 1, idx + n)
        local chunk = dat:sub(idx, nidx)
        idx = nidx
        return #chunk > 0 and chunk
    end)
end

function provider:du()
    return {
        free = 1024,
        used = 0,
        label="procfs"
    }
end

function provider:list(path)
    if provider.files[path] and provider.files[path].list then return provider.files[path].list() end
    return { 
        
    }
end

function provider:exists(path)
    if provider.files[path] then return true end
    return false
end


function provider:stat(path, ...)
    if provider.files[path] and provider.files[path].stat then return provider.files[path].stat() end
    return { 
        dev = -1, ino = -1, mode = 33234, nlink = 1,
        uid = 0, gid = 0, rdev = -1, size = 0, blksize = 2048,
        atime = 0, ctime = 0, mtime = 0
    }
end


function provider:open(path)
    checkArg(1, path, "string")
    local node, proc = path_to_node(path, 0)
    if node == nil then return nil, proc end

    if (not proc) and type(node) == "table" and node.data then
        local data = type(node.data) == "function" and node.data() or node.data
        return { file = to_fd(data), ioctl = node.ioctl }
    elseif type(node) ~= "table" then
        return { file = to_fd(node), ioctl = function()end }  
    else
        return nil, k.errno.EISDIR
    end
end

function provider:read(fd, n)
    checkArg(1, fd, "table")
    checkArg(1, n, "number")

    if fd.closed then return nil, k.errno.EBADF end
    if not fd.file then return nil, k.errno.EBADF end

    return fd.file:read(n)
end

function provider:close(fd)
    checkArg(1, fd, "table")
    fd.closed = true
end

function provider.ioctl(fd, method, ...)
    checkArg(1, fd, "table")
    checkArg(2, method, "string")

    if fd.closed then return nil, k.errno.EBADF end
    if not fd.file then return nil, k.errno.EBADF end
    if not fd.ioctl then return nil, k.errno.ENOSYS end

    return fd.ioctl(method, ...)
end

k.register_fstype("procfs", function(x)
    return x == "procfs" and provider
end)

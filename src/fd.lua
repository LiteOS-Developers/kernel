
k.printk(k.L_INFO, "fd")

k.fds = {}


--[[
    @param stream {read(), write(), seek(), close()}
    @param fd number or nil
]]
function k.create_fd(stream, fd)
    checkArg(1, stream, "table")
    checkArg(2, fd, "number", "nil")
    if fd then
        if k.fds[fd] then
            fd = nil
        end
    end
    if not fd then
        repeat
            fd = math.random(0, math.pow(2, 32)-1)
        until not k.fds[fd]
    end
    assert(not k.fds[fd], "Filedescriptor error")
    k.fds[fd] = {
        fd = fd,
        stream = stream
    }
    return fd
end

function k.close(fd)
    if k.fds[fd.fd] then
        k.fds[fd.fd].stream.close(fd.fd)
        k.fds[fd.fd] = nil
    else
        k.printf("No open file with fd found %s\n", dump(fd))
    end
end

function k.write(fd, data)
    if k.fds[fd] then
        return k.fds[fd].stream.write(data) or data:len()
    end
    return 0
end

function k.isOpen(fd)
    return not not k.fds[fd]
end

function k.read(fd, c)
    if k.fds[fd.fd] then
        return k.fds[fd.fd].stream.read(c)
    end
    error(string.format("Requested FileDescriptor does not exist %s", dump(fd)))
    return ""
end

function k.call(meth, fd, c)
    if k.fds[fd] then
        if not k.fds[fd].stream[meth] then return end
        return k.fds[fd].stream[meth](c)
    end
    return nil
end

function k.node(fd)
    return k.fds[fd].stream
end

function k.seek(fd, off, whe)
    if k.fds[fd] then
        return k.fds[fd].stream.seek(off, whe)
    end
    return nil
end

local function ebadf()
    return nil, k.errno.EBADF
end

function k.fd_from_rwf(read, write, close)
    checkArg(1, read, "function", write and "nil")
    checkArg(2, write, "function", read and "nil")
    checkArg(3, close, "function", "nil")

    return {
        read = read or ebadf, write = write or ebadf,
        close = close or function() end
    }
end
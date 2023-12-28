--#define DRV_ROOTFS
k.printk(k.L_INFO, "drivers/rootfs")
k.rootfs = {
    mountPaths = {}
}

local function getDevAndPath(_path)
    if _path:sub(1, 1) ~= "/" then _path = "/" .. _path end
    if k.rootfs.mountPaths[_path] ~= nil then return k.rootfs.mountPaths[_path].addr, "/" end 
    local parts = {}
    
    _path = string.sub(_path, 2, -1)
    for part in string.gmatch(_path, "([^/]+)") do
        table.insert(parts, part)
    end
    
    local i = #parts
    
    repeat
        local joined = ""
        for j=1,i do 
            joined = joined .."/" .. parts[j]   
        end

        if k.rootfs.mountPaths[joined] ~= nil then
            local resPath = ""
            for j=i+1,#parts do resPath = resPath .. "/"..parts[j] end
            return k.rootfs.mountPaths[joined].addr, resPath
        end
        i = i - 1
    until i == 0
    return k.rootfs.mountPaths["/"].dev, _path
end

local function parts(p)
    if p:sub(1, 1) == "/" then p = p:sub(2, -1) end
    local parts = {}
    for part in string.gmatch(p, "([^/]+)") do
        table.insert(parts, part)
    end
    return parts
end

local function verify_fd(fd, dir)
    checkArg(1, fd, "table")

    if not (fd.fd and fd.node) then
      error("bad argument #1 (file descriptor expected)", 2)
    end

    -- Casts both sides to booleans to ensure correctness when comparing
    if (not not fd.dir) ~= (not not dir) then
      error("bad argument #1 (cannot supply dirfd where fd is required, or vice versa)", 2)
    end
  end

-------------------------------------------

function k.rootfs.mount(addr, tPath, type_)
    checkArg(1, addr, "string", "table")
    checkArg(2, tPath, "string")
    checkArg(3, opts, "table", "nil")

    if not k.rootfs.mountPaths["/"] then
        if tPath ~= "/" then
            return nil, "Please Mount rootfs first"
        end
    end

    local dev = addr

    if type(addr) == "string" then
        local type_ = k.component.type(addr)
        local fs = k.fstypes[type_]
        if fs == nil then
            k.panic(string.format("No fstype for type %s found", type_))
        end
        fs = fs(addr)
        -- dev = k.component.proxy(addr)
        dev = fs
    end
    k.rootfs.mountPaths[tPath] = {dev=dev,type_=type_}
end

function k.rootfs.isMount (point)
    checkArg(1, point, "string")
    return k.rootfs.mountPaths[point] ~= nil
end

function k.rootfs.mounts()
    return k.rootfs.mountPaths
end

function k.rootfs.umount(point)
    checkArg(1, point, "string")
    
    if not api.isMount(point) then
        return false
    end
    k.rootfs.mountPaths[point] = nil
    return true
end

function k.rootfs.spaceUsed(path)
    checkArg(1, path, "string")
    local dev, _ = getDevAndPath(path)
    return dev.spaceUsed()
end

function k.rootfs.checkPermissions(path)
    checkArg(1, path, "string")
    local proc = k.current_process()
    if not proc then return {r=true, w=true, x=true} end -- system (kernel/No Process)
    local sid = proc.sid
    if sid == 0 then return {r=true, w=true, x=true} end -- system (kernel/No Session)

    local user = k.sessions[sid]
    local groups = {}
    local gids = {}
    for _, g in ipairs(user.groups) do
        groups[#groups+1] = g.name
        gids[#gids+1] = g.gid
    end
    if user.id == 0 then return {r=true, w=true, x=true} end -- system (kernel/No User)
    -- if table.contains(groups, "root") then return {r=true, w=true, x=true} end -- user is root (root group)

    local attrs = k.rootfs.getAttrs(path)
    if not attrs.mode or not attrs.uid or not attrs.gid then return {r=false, w=false, x=false, err="Mode, uid or gid is missing", attr=attrs} end
    local perms = {r=false, w=false, x=false}
    if user.id == attrs.uid then -- user is owner?
        perms.r = attrs.mode:sub(1,1) == "r"
        perms.w = attrs.mode:sub(2,2) == "w"
        perms.x = attrs.mode:sub(3,3) == "x"
    end
    if table.contains(gids, attrs.gid) then -- user inside of group
        perms.r = perms.r or attrs.mode:sub(4,4) == "r"
        perms.w = perms.w or attrs.mode:sub(5,5) == "w"
        perms.x = perms.x or attrs.mode:sub(6,6) == "x"
    end
    
    -- every other case
    perms.r = perms.r or attrs.mode:sub(7,7) == "r"
    perms.w = perms.w or attrs.mode:sub(8,8) == "w"
    perms.x = perms.x or attrs.mode:sub(9,9) == "x"
    return perms
end

function k.rootfs.open(path, m)
    checkArg(1, path, "string")
    checkArg(2, m, "string", "nil")
    m = m or "r"
    local mode = {}
    for i = 1, unicode.len(m) do
        mode[unicode.sub(m, i, i)] = true
    end
    local perms = k.rootfs.checkPermissions(path)
    if mode.w or mode.w and not perms.w then
        return nil, k.errno.EPERM
    elseif mode.r and not perms.r then
        return nil, k.errno.EPERM
    end

    local dev, aPath = getDevAndPath(path)
    local handle = dev:open(aPath, m)
    return k.create_fd({
        write = function(fd, buf)
            return dev:write(handle, buf)
        end,
        seek = function(off, wh)
            return dev:seek(handle, wh, off)
        end,
        read = function(c)
            return dev:read(handle, c)
        end,
        close = function()
            dev:close(handle)
        end
    })
end

function k.rootfs.seek(fd, off, wh)
    checkArg(1, fd, "number")
    checkArg(2, _whence, "number")
    checkArg(3, offset, "number")
    if not k.isOpen(fd) then return nil, k.errno.EBADFD end
    return k.seek(fd, off, wh)
end

function k.rootfs.makeDirectory(path)
    checkArg(1, path, "string")
    local dev, aPath = getDevAndPath(path)
    return dev.makeDirectory(aPath)
end

function k.rootfs.exists(path)
    local dev, aPath = getDevAndPath(path)
    return dev:exists(aPath)
end

function k.rootfs.isReadOnly(path)
    checkArg(1, path, "string")
    local dev, _ = getDevAndPath(path)
    return dev.isReadOnly()
end

function k.rootfs.write(fd, buf)
    checkArg(1, fd, "number")
    checkArg(2, buf, "string")
    if not k.isOpen(fd) then return nil, k.errno.ECLOSED end
    return k.write(fd)
end

function k.rootfs.spaceTotal(path)
    checkArg(1, path, "string")
    local dev, _ = getDevAndPath(path)
    return dev.spaceTotal()
end

function k.rootfs.isDirectory(path)
    -- checkArg(1, path, "string")
    local dev, aPath = getDevAndPath(path)
    return dev:get_attributes(aPath).mode & k.perms.FS_DIR == 0x4000
end

function k.rootfs.rename(from, to)
    checkArg(1, from, "string")
    checkArg(2, to, "string")
    local dev, aFrom = getDevAndPath(path)
    local dev2, aTo = getDevAndPath(path)
    if dev.addr ~= dev2.addr then return nil, k.errno.EDEVSWT end
    return k.component.invoke(addr, "rename", aFrom, aTo)
end

function k.rootfs.list(path)
    checkArg(1, path, "string")
    local dev, aPath = getDevAndPath(path)
    return dev.list(aPath)
end

function k.rootfs.lastModified(path)
    checkArg(1, path, "string")
    local dev, aPath = getDevAndPath(path)
    return dev.lastModified(aPath)
end

function k.rootfs.getLabel(path)
    checkArg(1, path, "string")
    local dev, aPath = getDevAndPath(path)
    return dev.getLabel()
end
function k.rootfs.remove(path)
    checkArg(1, path, "string")
    local addr, aPath = getDevAndPath(path)
    return dev.remove(aPath)
end

function k.rootfs.close(fd)
    checkArg(1, fd, "number")
    if not k.isOpen(fd) then return nil, k.errno.EBADFD end
    k.close(fd)
end

function k.rootfs.size(path)
    checkArg(1, path, "string")
    local addr, aPath = getDevAndPath(path)
    return dev.size(aPath)
end

function k.rootfs.read(fd, count)
    checkArg(1, fd, "number")
    checkArg(2, count, "number")
    if not k.isOpen(fd) then return nil, k.errno.ECLOSED end
    return k.read(fd, count)
end

function k.rootfs.setLabel(path, value)
    checkArg(1, path, "string")
    checkArg(2, value, "string")
    local dev, aPath = getDevAndPath(path)
    return dev.setLabel(value)
end

---------------------------------------

function k.rootfs.getAttrs(path)
    checkArg(1, path, "string")
    local addr, aPath = getDevAndPath(path)
    return dev.getAttrs(aPath)
end

function k.rootfs.ensureOpen(fd)
    checkArg(1, fd, "number")
    return k.isOpen(fd)
end
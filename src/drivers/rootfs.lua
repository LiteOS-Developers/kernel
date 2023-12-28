--#skip 13
--[[
    Copyright (C) 2023 thegame4craft

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]--

--#define DRV_ROOTFS
k.printk(k.L_INFO, "drivers/rootfs")
local mounts = {}


local default_proc = { uid = 0, gid = 0 }
local function cur_proc()
    return k.current_process() or default_proc
end

local function path_to_node(path)
    path = k.check_absolute(path)

    local current = k.current_process()
    if current then
        path = k.clean_path(current.root .. "/" .. path)
    end

    local mnt, rem = "/", path
    for m in pairs(mounts) do
        if path:sub(1, #m) == m and #m > #mnt then
            mnt, rem = m, path:sub(#m+1)
        end
    end

    if #rem == 0 then rem = "/" end

    return mounts[mnt], rem or "/"
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

-----------------------------------------------

function k.du(path)
    checkArg(1, path, "string")
    local node, _ = path_to_node(path)
    if not node.du then return nil, k.errno.ENOSYS end
    return node:du()
end

function k.check_absolute(path)
    checkArg(1, path, "string")

    if path:sub(1, 1) == "/" then
        return "/" .. table.concat(k.split_path(path), "/")

    else
        local current = k.current_process()
        local cwd = current and current.cwd or "/"
        return "/" .. table.concat(k.split_path(cwd .. "/" .. path), "/")
    end
end

function k.move(from, to)
    checkArg(1, from, "string")
    checkArg(2, to, "string")
    from = k.check_absolute(from)
    to = k.check_absolute(to)
    
    from_node, from_remain = path_to_node(from)
    to_node, to_remain = path_to_node(to)

    if not from_node:exists(from_remain) then return nil, k.errno.ENOENT end
    if to_node:exists(to_remain) then return nil, k.errno.EEXIST end
    local to_segments = k.split_path(to_remain)
    local to_parent = "/" .. table.concat(to_segments, "/", 1, #to_segments - 1)
    if not to_node:exists(to_parent) then return nil, k.errno.ENOENT end

    if from_node.address == to_node.address then
        from_node:rename(from_remain, to_remain)
    else
        if to_node:stat(to_parent).mode & k.perm.FS_DIR == 0 then
            return nil, k.errno.ENOTDIR
        end
        if to_node:stat(to_remain).mode & k.perm.FS_DIR ~= 0 then
            return nil, k.errno.EISDIR
        end
        assert(false, "Operation not supported")
    end
end

function k.remove(path)
    checkArg(1, path, "string")
    local node, remain = path_to_node(path)

    if not node.remove then return nil, k.errno.ENOSYS end
    return node:remove(remain)
end


function k.clean_path(path)
    checkArg(1, path, "string")
    return "/" .. table.concat(k.split_path(path), "/")
end

function k.mount(device, path)
    checkArg(1, device, "string", "table")
    checkArg(2, path, "string")
    path = k.check_absolute(path)
    local proxy = device
    
    if type(device) == "string" then
        local type_ = component.type(device)
        if not type_ then
            if k.fstypes[device] then
                proxy = k.fstypes[device](device)
            else
                return nil, k.errno.ENODEV
            end
        elseif type_ == "filesystem" then
            proxy = k.fstypes["managed"](device)
        else
            return nil, k.errno.ENODEV
        end
    end

    proxy.mountType = proxy.mountType or "managed"
    mounts[path] = proxy
    if not proxy.address then
        k.panic(string.format("Filesystem %s has no address", dump(device)))
    end
    if proxy.mount then proxy:mount(path) end
    return true
end

function k.isMount(path)
    return not not mounts[path]
end

function k.umount(path)
    checkArg(1, path, "string")
    path = k.clean_path(path)
    if not mounts[path] then
        return nil, k.errno.EINVAL
    end

    local node = mounts[path]
    if node.unmount then
        node:unmount(path)
    end
    mounts[path] = nil
    return true
end

local opened = {}

function k.open(file, mode)
    checkArg(1, file, "string")
    checkArg(2, mode, "string")
    
    local node, remain = path_to_node(file)
    if not node.open then
        return nil, k.errno.ENOSYS
    end
    local exists = node:exists(remain)
    local segs = k.split_path(remain)
    local dir = "/" .. table.concat(segs, "/", 1, #segs - 1)
    local base = segs[#segs]
    local modes = {}
    for i=1,#mode,1 do
        modes[mode:sub(i,i)] = true
    end
    
    local stat, err
    if not exists and (not modes.w and not modes.a) then
        return nil, k.errno.ENOENT
    elseif not exists and table.contains({"w", "a"}, mode) then
        stat, err = node:stat(dir)
    else
        stat, err = node:stat(remain)
    end
    if not stat then
        return nil, err or -2
    end

    if not k.process_has_permission(cur_proc(), stat, "x") then
        return nil, k.errno.EACCES
    end
    
    local fd, err, sys_e = node:open(remain, mode)
    
    if not fd then
        k.printk(k.L_NOTICE, "rootfs:206 %s %s %s", tostring(exists), remain, sys_e or "<SYS_e>")
        return nil, err or -2
    end

    local stream = k.create_fd({
        read = modes.r and (function(fmt)
            checkArg(1, fmt, "string", "number")
            if fmt == "*a" then
                fmt = stat.size
            elseif type(fmt) == "string" then
                return nil, k.errno.EINVAL
            end
            return node:read(fd, tonumber(fmt or "1") or 1)
        end) or nil,
        write = modes.w and (function(buf)
            checkArg(1, buf, "string")
            return node:write(fd, buf)
        end) or nil,
        seek = function(off, wh)
            checkArg(1, off, "number")
            checkArg(2, wh, "string")
            return node:seek(fd, off, wh)
        end,
        close = function()
            return node:close(fd)
        end,
        ioctl = function(call, ...)
            return table.unpack({node:ioctl(fd, call, ...)})
        end
    })
    
    local ret = { fd = stream, node = k.node(stream), refs = 1 }
    opened[ret] = true
    return ret, 0
end

function k.ioctl(fd, op, ...)
    verify_fd(fd)
    checkArg(2, op, "string")

    if op == "setcloexec" then
        fd.cloexec = not not ...
        return true
    end
    if not fd.node.ioctl then return nil, k.errno.ENOSYS end
    return table.unpack({fd.node.ioctl(op, ...)})
end

local stat_defaults = {
    dev = -1, ino = -1, mode = 0x81FF, nlink = 1,
    uid = 0, gid = 0, rdev = -1, size = 0, blksize = 2048,
    atime = 0, ctime = 0, mtime = 0
}

function k.list(path)
    checkArg(1, path, "string")
    path = k.check_absolute(path)
    local node, remain = path_to_node(path)
    if not node.list then return nil, k.errno.ENOSYS end
    if not node:exists(remain) then return nil, k.errno.ENOENT end
    local stat = node:stat(remain)
    if not k.process_has_permission(cur_proc(), stat, "r") then
        return nil, k.errno.EACCES
    end
    local files = node:list(remain)
    for dir, _ in pairs(mounts) do
        local segments = k.split_path(dir)
        local parent = "/" .. table.concat(segments, "/", 1, #segments - 1)
        if parent == path then
            if segments[#segments] ~= nil then
                files[#files + 1] = segments[#segments] .. "/"
            end
        end
    end
    -- k.printf("%s\n", dump(table.keys(mounts)))
    return files
end

function k.stat(path)
    checkArg(1, path, "string")
    local node, remain = path_to_node(path)
    if not node.stat then return nil, k.errno.ENOSYS end
    local statx, errno = node:stat(remain)
    if not statx then return nil, errno end
    for key, val in pairs(statx) do
        statx[key] = statx[key] or val
    end
    return statx
end
function k.mkdir(path)
    checkArg(1, path, "string")
    local node, remain = path_to_node(path)
    if not node.mkdir then return nil, k.errno.ENOSYS end
    if node:exists(remain) then return nil, k.errno.EEXIST end

    local segments = k.split_path(remain)
    local parent = "/" .. table.concat(segments, "/", 1, #segments - 1)

    local statx = node:stat(parent)
    if not stat then return nil, k.errno.ENOENT end
    if not k.process_has_permission(cur_proc(), stat, "w") then
        return nil, k.errno.EACCES
    end

    local umask = (cur_proc().umask or 0) ~ 511
    local done, failed = node:mkdir(remain)
    if not done then return nil, failed end
    if node.chmod then node:chmod(remain, ((mode or stat.mode) & umask)) end

    return done, failed
end

function k.link(...)
    error("NotImplemented: k.link(...)")
end
function k.unlink(...)
    error("NotImplemented: k.unlink(...)")
end

function k.chmod(path, mode)
    checkArg(1, path, "string")
    checkArg(2, mode, "number")

    local node, remain = path_to_node(path)
    if not node.chmod then return nil, k.errno.ENOSYS end
    if not node:exists(remain) then return nil, k.errno.ENOENT end

    local stat = node:stat(remain)
    if not k.process_has_permission(cur_proc(), stat, "w") then
        return nil, k.errno.EACCES
    end

    -- only preserve the lower 12 bits
    mode = (mode & 0x1FF)
    return node:chmod(remain, mode)
end

function k.chown(path, uid, gid)
    checkArg(1, path, "string")
    checkArg(2, uid, "number")
    checkArg(3, gid, "number")

    local node, remain = path_to_node(path)
    if not node.chown then return nil, k.errno.ENOSYS end
    if not node:exists(remain) then return nil, k.errno.ENOENT end

    local stat = node:stat(remain)
    if not k.process_has_permission(cur_proc(), stat, "w") then
        return nil, k.errno.EACCES
    end

    return node:chown(remain, uid, gid)
end

function k.mounts()
    return mounts
end

function k.isDir(path)
    checkArg(1, path, "string")
    if k.isMount(path) then return true end
    local stat = k.stat(path)
    if not stat then return false, k.errno.ENOENT end
    return stat.mode & k.perm.FS_DIR ~= 0
end

k.event.listen("shutdown", function()
    for fd in pairs(opened) do
      fd.refs = 1
      k.close(fd)
    end

    for path in pairs(mounts) do
      k.unmount(path)
    end
end)
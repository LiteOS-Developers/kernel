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

k.printk(k.L_INFO, "drivers/fs/managed")

do
    local provider = {}

    local function is_attribute(path)
        return path:sub(-5,-1) == ".attr"
    end

    local function load_attributes(data)
        local attributes = {}
    
        for line in data:gmatch("[^\n]+") do
            local key, val = line:match("^(.-):(.+)$")
            attributes[key] = tonumber(val)
        end
    
        return attributes
    end

    local function attr_path(path)
        local segments = k.split_path(path)
        if #segments == 0 then return "/.attr" end
    
        return "/" .. table.concat(segments, "/", 1, #segments - 1) .. "/." ..
            segments[#segments] .. ".attr"
    end

    function provider:exists(path)
        checkArg(1, path, "string")
        return self.fs.exists(path)
    end

    function provider:remove(path)
        if is_attribute(path) then return nil, k.errno.EACCES end
        if not self:exists(path) then return nil, k.errno.ENOENT end

        return self.fs.remove(path)
    end

    function provider:list(path)
        checkArg(1, path, "string")
    
        if is_attribute(path) then return nil, k.errno.EACCES end
        if not self:exists(path) then return nil, k.errno.ENOENT end
        if not self.fs.isDirectory(path) then return nil, k.errno.ENOTDIR end
    
        local files = self.fs.list(path)
        for i=#files, 1, -1 do
            if is_attribute(files[i]) then table.remove(files, i) end
        end
        return files
    end

    function provider:stat(path)
        checkArg(1, path, "string")
        
        if is_attribute(path) then return nil, k.errno.EACCES end
        if not self:exists(path) then return nil, k.errno.ENOENT end
    
        local attributes = self:get_attributes(path)
        -- TODO: populate the 'dev' and 'rdev' fields?
        local stat = {
            dev = -1,
            ino = -1,
            mode = attributes.mode,
            nlink = 1,
            uid = attributes.uid,
            gid = attributes.gid,
            rdev = -1,
            size = self.fs.isDirectory(path) and 512 or self.fs.size(path),
            blksize = 2048,
            ctime = attributes.created,
            atime = math.floor(computer.uptime() * 1000),
            mtime = self:lastModified(path)*1000
        }
    
        stat.blocks = math.ceil(stat.size / 512)
    
        return stat
    end

    function provider:lastModified(file)
        local last = self.fs.lastModified(file)
    
        if last > 9999999999 then
          return math.floor(last / 1000)
        end
    
        return last
      end

    function provider:get_attributes(file)
        checkArg(1, file, "string")
    
        if is_attribute(file) then return nil, k.errno.EACCES end
    
        local fd = self.fs.open(attr_path(file), "r")
        if not fd then
            -- default to root/root, rwxrwxrwx permissions
            return {
                uid = k.syscalls and k.syscalls.geteuid() or 0,
                gid = k.syscalls and k.syscalls.getegid() or 0,
                mode = self.fs.isDirectory(file) and 0x41A4 or 0x81A4,
                created = self:lastModified(file)
            }
        end
    
        local data = self.fs.read(fd, 2048)
        self.fs.close(fd)
    
        local attributes = load_attributes(data or "")
        attributes.uid = attributes.uid or 0
        attributes.gid = attributes.gid or 0
        -- default to root/root, rwxrwxrwx permissions
        attributes.mode = attributes.mode or (self.fs.isDirectory(file)
          and 0x4000 or 0x8000) + (0x1FF ~ k.current_process().umask)
        attributes.created = attributes.created or self:lastModified(file)
    
        return attributes
    end

    function provider:set_attributes(file, attributes)
        checkArg(1, file, "string")
        checkArg(2, attributes, "table")
    
        if is_attribute(file) then return nil, k.errno.EACCES end
    
        local fd = self.fs.open(attr_path(file), "w")
        if not fd then return nil, k.errno.EROFS end
    
        self.fs.write(fd, dump_attributes(attributes))
        self.fs.close(fd)
        return true
    end

    function provider:du()
        return {
            total = self.fs.spaceTotal(),
            used = self.fs.spaceUsed(),
            label = self.fs.getLabel()
        }
    end

    function provider:chmod(path, mode)
        checkArg(1, path, "string")
        checkArg(2, mode, "number")
    
        if is_attribute(path) then return nil, k.errno.EACCES end
        if not self:exists(path) then return nil, k.errno.ENOENT end
    
        local attributes = self:get_attributes(path)
        -- userspace can't change the file type of a file
        attributes.mode = ((attributes.mode & 0xF000) | mode)
        return self:set_attributes(path, attributes)
    end

    function provider:chown(path, uid, gid)
        checkArg(1, path, "string")
        checkArg(2, uid, "number")
        checkArg(3, gid, "number")
    
        if is_attribute(path) then return nil, k.errno.EACCES end
        if not self:exists(path) then return nil, k.errno.ENOENT end
    
        local attributes = self:get_attributes(path)
        attributes.uid = uid
        attributes.gid = gid
    
        return self:set_attributes(path, attributes)
      end

    function provider:mkdir(path)
        checkArg(1, path, "string")
        return (not is_attribute(path)) and self.fs.makeDirectory(path)
    end

    function provider:open(path, mode)
        checkArg(1, path, "string")
        checkArg(2, mode, "string")

        if is_attribute(path) then return nil, k.errno.EACCES end

        if self.fs.isDirectory(path) then
            return nil, k.errno.EISDIR
        end
        local fd, e = self.fs.open(path, mode)
        if not fd then return nil, k.errno.ENOENT, e else return fd end
    end

    function provider:read(fd, count)
        checkArg(1, fd, "table")
        checkArg(2, count, "number")

        return self.fs.read(fd, count)
    end
    function provider:write(fd, buf)
        checkArg(1, fd, "table")
        checkArg(2, buf, "string")

        return self.fs.write(fd, buf)
    end
    function provider:seek(fd, off, whe)
        checkArg(1, fd, "table")
        checkArg(2, off, "number")
        checkArg(3, whe, "string")

        return self.fs.seek(fd, whe, off)
    end
    function provider:flush() end
    function provider:close(fd)
        checkArg(1, fd, "table")
        if fd.index then return true end
        return self.fs.close(fd)
    end
    local fs_mt = { __index = provider }

    k.register_fstype("managed", function(comp)
        if type(comp) == "table" and comp.type == "filesystem" then
            return setmetatable({fs = comp, address = comp.address:sub(1,8)}, fs_mt)
    
        elseif type(comp) == "string" and component.type(comp) == "filesystem" then
            return setmetatable({fs = component.proxy(comp), address = comp:sub(1,8)}, fs_mt)
        end
    end)
    
    k.register_fstype("tempfs", function(t)
        if t == "tempfs" then
            local node = k.fstypes.managed(computer.tmpAddress())
            node.address = "tempfs"
            return node
        end
    end)

end

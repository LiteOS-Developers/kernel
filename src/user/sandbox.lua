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

k.printk(k.L_INFO, "user/sandbox")
k.sandbox = {}

local function copyBlacklist(t, list)
    local new = deepcopy(t)
    for key in pairs(list) do new[key] = nil end
    return new
end


local blacklist = {
    k = true, lib = true, component = true, _G = true, e = true, computer = true, _VERSION = true,
    rawset = true, rawget = true, rawlen = true, rawequal = true, debug = true, os = true
}

k.max_proc_time = tonumber(k.cmdline.max_proc_time or "3") or 3

k.sandbox.new = function(opts)
    checkArg(1, opts, "table", "nil")
    opts = opts or {}
    opts.base = opts.base or _G

    local new = deepcopy(base or _G)
    for key, v in pairs(blacklist) do new[key] = nil end
    
    new.umask = k.umask
    new.umask_to_str = k.umask_to_str

    new.load = function(a, b, c, d)
        return load(a, b, c, d or k.current_process().env)
    end
    new.error = function(l)
        local info = debug.getinfo(3)
        k.printf("%s:%d: %s\n", info.short_src, tostring(info.currentline), l)
        for _, line in ipairs(split(debug.traceback(), "\n")) do
            line = line:gsub("\t", "  ")
            k.printf("%s\n", line)
        end
        local proc = k.current_process()
        proc.is_dead = true
        coroutine.yield()
    end
    new.printf = function(format, ...)
        local msg = string.format(format, ...)
        local m, e = k.parse_ansi(msg)
        if not m then error(e) end
        for idx, parts in ipairs(m) do
            for i, part in ipairs(parts) do
                if #table.keys(part) ~= 0 then
                    -- k.printf("%s\n", dump(part))
                    --[[]]
                    if part.foreground and part.foreground <= 9 then
                        gpu.setForeground(part.foreground, true)
                    end
                    if part.background and part.background <= 9 then
                        gpu.setBackground(part.background, true)
                    end
                    if part.line then
                        k.cursor:move(part.line, nil)
                    end
                    if part.column then
                        k.cursor:move(nil, part.column)
                    end
                    if part.cmd == "store_dec" then
                        part.func(k.cursor:getX(), k.cursor:getY())
                    end
                    if part.cmd == "clear_screen" then
                        gpu.fill(1, 1, k.cursor:getWidth(), k.cursor:getHeight(), " ")
                    end
                    if part.content then
                        k.printf("%s", part.content)
                    end
                end
            end            
        end
        -- k.printf(format, ...)
    end

    errno = deepcopy(k.errno)

    new.dofile = function(path)
        local res, e = k.loadfile(path, new)
        if not res then
            return nil, e
        end
        return res()
    end

    new.package = new.dofile("/lib/package.lua")
    new.package.loaded["package"] = new.package
    new.package.loaded["buffer"] = k.buffer
    new.require = new.package.load

    new.computer = {
        uptime = computer.uptime,
        freeMemory = computer.freeMemory,
        totalMemory = computer.totalMemory,
    }

    new.io = {
        stdin = k.io.stdin
    }
    local cyield = new.coroutine.yield
    local yield = function(...) 
        k.current_process().bg = gpu.setBackground(0, true)
        k.current_process().fg = gpu.setForeground(7, true)
        local v = {cyield(...)}

        gpu.setBackground(k.current_process().bg)
        gpu.setForeground(k.current_process().fg)
        return table.unpack(v)
    end

    function new.coroutine.yield(request, ...)
        local proc = k.current_process()
        local last_yield = proc.last_yield or computer.uptime()

        -- local info = debug.getinfo(3)
        -- k.printk(k.L_DEBUG, "%s:%.0f (%s)", info.short_src, info.currentline, info.name)

        if request == "syscall" then
            if computer.uptime() - last_yield > k.max_proc_time then
                --coroutine.yield(k.sysyield_string)
                proc.last_yield = computer.uptime()
            end
            
            return table.unpack(table.pack(k.perform_system_call(...)))
        end
        
        proc.last_yield = computer.uptime()
        if request == nil then
            return yield(k.sysyield_string)
        end
        return yield(request, ...)
    end

    function new.ioctl(fd, func, ...)
        return table.unpack(table.pack(new.syscall("ioctl", fd, func, ...)))
    end

    function new.syscall(call, ...)
        return table.unpack(table.pack(new.coroutine.yield("syscall", call, ...)))
    end

    new._G = new

    local proc = k.current_process()
    if proc and k.stat(proc.shell) ~= nil and not k.isDir(proc.shell) then
        local handle = k.open(proc.shell, "r")
        local r, e = load([[require("shell")]], "LoadShell", "bt", new)
        if not r then
            new.error("Failed to create Envoirement: " .. e)
            return nil
        end
        new.package.loaded["shell"] = r()
    end
    
    return new
end

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

k.printk(k.L_INFO, "user/exec")

function k.loadfile(file, env)
    local buf = ""
    local chunk
    local handle = k.open(file, "r")
    repeat
        chunk = k.read(handle, math.huge)
        buf = buf .. (chunk or "")
    until not chunk
    k.close(handle)
    return load(buf, "=" .. file, "t", env)
end

function k.load_executable(file, env)
    checkArg(1, file, "string")
    checkArg(2, env, "table", "nil")
    
    local current = k.current_process()
    local content,e = k.readfile(file)
    if not content then
        error(string.format("readfile('%s') returned error %d", file, e))
    end
    local func,err = load(content, "="..file, "t", env or current.env)
    if not func then
        k.printk(k.L_DEBUG, "Load of executable failed")
        k.printk(k.L_DEBUG, "Reason: %s", err)
        return nil, k.errno.ENOEXEC
    end

    local result = table.pack(xpcall(func, debug.traceback, args))
    if not result[1] then
        k.printk(k.L_NOTICE, "Lua error: %s", result[2])
        return nil, "LUA ERROR"
    end
    local tbl = result[2]
   
    local r = function(args)
        local result = table.pack(xpcall(tbl.main, debug.traceback, args))
        if not result[1] then
            local lines = split(result[2], "\n")
            k.printk(k.L_NOTICE, "Lua error: %s", lines[1])
            for i = 2,#lines do
                k.printk(k.L_NOTICE, "| %s", lines[i])
            end
            if #lines > 1 then
                k.printk(k.L_NOTICE, "========")
            end
            k.syscalls.exit(1)
        else
            k.syscalls.exit(0)
        end
    end
    return r
end

k.exec = function(file, args, wait)
    checkArg(1, file, "string")
    checkArg(2, args, "table", "nil")
    checkArg(3, wait, "boolean", "nil")
    args = args or {}
    wait = wait == nil and true or wait

    local process = k.get_process(k.add_process())
    process.cmdline = {file, table.unpack(args)}
    local exec = k.load_executable(file, process.env)
    local thread = k.create_thread(function()
        exec(args)
    end)
    -- process.cmdline = args
    process:addThread(thread)
end

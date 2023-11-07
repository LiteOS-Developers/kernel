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
k.printk(k.L_INFO, "scheduler/scheduler")

k.threadIdx = 0
k.nextThread = function()
    local keys = table.keys(k.threading.threads)
    local allDead = true
    for _, key in ipairs(keys) do
        if not k.threading.threads[key].stopped then 
            allDead = false
            break
        end
    end
    if allDead then return nil end
    if #keys == 0 then return nil end
    if k.threadIdx >= #keys then
        k.threadIdx = 0
    end
    k.threadIdx = k.threadIdx + 1
    local thread = k.threading.threads[keys[k.threadIdx]]
    if thread.stopped then 
        local pid, thread = k.nextThread()
        return pid, thread
    end
    return keys[k.threadIdx], thread
end

k.schedule = function(pid, thread)
    if coroutine.status(thread.coro) == "dead" then
        k.threading.threads[pid]:stop()
        return {nil, n=1}
    end
    return table.pack(coroutine.resume(thread.coro))
    -- if not result[1] then
    --     k.write(dump(result[2]))
    -- end
    -- if coroutine.status(v.coro) == "dead" then
    --     k.threading.threads[pid].result = result[2]
    --     k.threading.threads[pid]:stop()
    --     goto continue
    -- end
    -- if result[2] == "syscall" then
    --     result = table.pack(coroutine.resume(v.coro, table.unpack({k.processSyscall(result)})))
    -- end
    -- ::continue::
    -- event.fetch()
end
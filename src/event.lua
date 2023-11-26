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

k.printk(k.L_INFO, "event")

k.event = {
    listeners = {},
}

function k.event.listen(e, func)
    checkArg(1, e, "string")
    checkArg(2, func, "function")
    local id
    if not k.event.listeners[e] then k.event.listeners[e] = {} end
    repeat
        id = math.random(0, math.pow(2, 32)-1)
    until not k.event.listeners[e][id]
    k.event.listeners[e][id] = func
    return id
end

function k.event.cancleListener(e, id)
    checkArg(1, e, "string")
    checkArg(2, id, "number")

    if not k.event.listeners[e][id] then
        return nil, k.errno.EINVAL
    end
    k.event.listeners[e][id] = false
    return true
end

function k.event.push(event)
    if event.n < 1 then return end
    if #k.event.listeners == 0 then return end
    local handlers = k.event.listeners[event[1]]
    for _, h in ipairs(handlers) do
        h(table.unpack(event))
    end
end

function k.event.pull(type)
    while true do
        local event = table.pack(computer.pullSignal(0.02))
        if event ~= nil then
            k.event.push(event)
            if event[1] == type then return table.unpack(event) end
        end
    end
end

function k.event.tick()
    local event = table.pack(computer.pullSignal(0.02))
    k.event.push(event)
end

function k.pushSignal(sig, ...)
    assert(sig ~= nil, "bad argument #1 to 'pushSignal' (value expected, got nil)")

    computer.pushSignal(sig, ...)
    return true
end

function k.pullSignal(timeout)
    local sig = table.pack(computer.pullSignal(timeout))
    if sig.n == 0 then return end
    k.event.push(sig)
    return table.unpack(sig, 1, sig.n)
end
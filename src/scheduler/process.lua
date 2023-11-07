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

k.printk(k.L_INFO, "scheduler/process")

local process = {}

local default_parent = {
    cmdline = "",
    pid = 0,
    pgid = 0,
    sid = 0,
    environ = {},
    fds = {}
}

function process:addThread(t)
    local info = debug.getinfo(3)
    table.sort(info)
    self.threads[self.thread_count + 1] = t
    self.thread_count = self.thread_count + 1 
end

function process:resume(sig, ...)
    local time = os.time()
    -- We handle user-provided signals this way because otherwise
    -- a signal handler calling exit() would make the sending process
    -- exit, not the receiving one.  And we handle them here because
    -- otherwise processes wouldn't respond to SIGCONT.
    while #self.sigqueue > 0 do
        local psig = table.remove(self.sigqueue, 1)
        if sigtonum[psig] then
            self.status = sigtonum[psig]
            self:signal(psig)
        end
    end
    
    if self.stopped then 
        k.printk(k.L_NOTICE, "STOPPED")
        return
    end

    sig = table.pack(sig, ...)

    local resumed = false
    if sig and sig.n > 0 and #self.queue < 256 then
        self.queue[#self.queue + 1] = sig
    end

    local signal = default
    if #self.queue > 0 then
        signal = table.remove(self.queue, 1)

    elseif self:deadline() > computer.uptime() then
        k.hlt()
        return
    end

    for i, thread in pairs(self.threads) do
        self.current_thread = i
        local result = thread:resume(table.unpack(signal, 1, signal.n))
        resumed = resumed or not not result
        -- k.printf("%s: %s %s\n", dump(self.threads[self.current_thread]), tostring(resumed), dump(k.current_process().cmdline))

        if result == 1 then
            self.threads[i] = nil
            self.thread_count = self.thread_count - 1
            table.insert(self.queue, {"thread_died", i})
        end
    end

    self.runtime = self.runtime + (os.time() - time)

    return resumed
end

function process:deadline()
    local deadline = math.huge
    for _, thread in pairs(self.threads) do
        if thread.deadline < deadline then
            deadline = thread.deadline
        end

        if thread.status == "y" then
            return -1
        end

        if thread.status == "w" and #self.queue > 0 then
            return -1
        end
    end
    return deadline
end

k.default_signal_handlers = setmetatable({
    SIGTSTP = function(p)
        p.stopped = true
    end,

    SIGSTOP = function(p)
        p.stopped = true
    end,

    SIGCONT = function(p)
        p.stopped = false
    end,

    SIGTTIN = function(p)
        printk(k.L_DEBUG, "process %d (%s) got SIGTTIN", p.pid, p.cmdline[0])
        p.stopped = true
    end,

    SIGTTOU = function(p)
        printk(k.L_DEBUG, "process %d (%s) got SIGTTOU", p.pid, p.cmdline[0])
        p.stopped = true
    end
    }, {
    __index = function(t, sig)
        t[sig] = function(p)
            p.threads = {}
            p.thread_count = 0
        end

        return t[sig]
    end
})

function process:signal(sig, imm)
    if self.signal_handlers[sig] then
        printk(k.L_DEBUG, "%d: using custom signal handler for %s", self.pid, sig)
        pcall(self.signal_handlers[sig], sigtonum[sig])

    else
        printk(k.L_DEBUG, "%d: using default signal handler for %s", self.pid, sig)
        pcall(k.default_signal_handlers[sig], self)
    end

    if self.thread_count == 0 then
        self.reason = "signal"
    end

    if imm and (self.stopped or self.thread_count == 0) then
        coroutine.yield(0)
    end
end

function k.create_process(pid, parent, opts)
    parent = parent or default_parent
    opts = opts or {}
    local new = setmetatable({
        queue = {},
        stopped = false,
        threads = {},
        thread_count = 0,
        current_thread = 0,
        cmdline = {[0]=parent.cmdline and parent.cmdline[0] or "nil"},

        exit_status = nil,
        reason = "",
        pid = pid or k.newpid(),
        ppid = parent.pid,

        pgid = parent.pgid,
        sid = parent.sid,

        uid = parent.uid or 0,
        gid = parent.gid or 0,

        euid = parent.euid or 0,
        egid = parent.egid or 0,

        suid = parent.uid or 0,
        sgid = parent.gid or 0,

        cwd = parent.cwd or "/",
        root = parent.root or "/",
        shell = parent.shell or "/dev/tty0",

        colors = {fg = 0, bg = 0},
        fds = {},
        handlers = {},
        signal_handlers = {},
        sigqueue = {},
        env = k.sandbox.new(),
        umask = parent.umask or k.umask("rw-r--r--"),

        runtime = 0,
        environ = setmetatable({}, {__index=parent.environ,
        __pairs = function(tab)
            local t = {}
            for k, v in pairs(parent.environ) do
                t[k] = v
            end

            for k,v in next, tab, nil do
                t[k] = v
            end

            return next, t, nil
        end, __metatable = {}})
    }, {
        __index = process
    })

    for k, v in pairs(parent.fds) do
        new.fds[k] = v
        v.refs = v.refs + 1
    end

    return new
end

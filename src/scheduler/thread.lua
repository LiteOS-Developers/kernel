k.printk(k.L_INFO, "scheduler/thread")

do
    local sysyield_string = ""

    for i=1, math.random(3, 5), 1 do
        sysyield_string = sysyield_string .. string.format("%02x", math.random(0, 255))
    end

    local function rand_char()
        local area = math.random(1, 3)
        if area == 1 then -- number
            return string.char(math.random(48, 57))
        elseif area == 2 then -- uppercase letter
            return string.char(math.random(65, 90))
        elseif area == 3 then -- lowercase letter
            return string.char(math.random(97, 122))
        end
    end

    for i=1, math.random(3, 5), 1 do
        sysyield_string = sysyield_string .. rand_char()
    end

    k.sysyield_string = sysyield_string
end

local function sysyield()
    local proc = k.current_process()
    proc.last_yield = proc.last_yield or computer.uptime()
    local last_yield = proc.last_yield

    if computer.uptime() - last_yield >= 0.1 then
        if pcall(coroutine.yield, k.sysyield_string) then
            proc.last_yield = computer.uptime()
        end
    end
end

local thread = {}


function thread:resume(sig, ...)
    if sig and #self.queue < 256 then
        table.insert(self.queue, table.pack(sig, ...))
    end

    local resume_args

    -- if we were forcibly yielded, we do *not* pass anything to .resume().
    -- if status is "w", then only resume if either the timeout has been
    -- exceeded or there is a signal in the queue.
    if self.status == "w" then
        if computer.uptime() <= self.deadline and #self.queue == 0 then return end

        if #self.queue > 0 then
            resume_args = table.remove(self.queue, 1)
        end

    -- if status is "s", then don't resume, ever, until the status is no longer
    -- "s".  See thread:stop() and thread:continue().
    elseif self.status == "s" then
        return false
    end

    local result
    self.status = "r"

    if resume_args then
        result = table.pack(coroutine.resume(self.coro, table.unpack(resume_args, 1, resume_args.n)))
    else
        result = table.pack(coroutine.resume(self.coro))
    end


    -- first return is a boolean, we don't need that
    if type(result[1]) == "boolean" then
        if not result[1] then
            k.printk(k.L_EMERG, result[2])
        else
            -- k.printk(k.L_EMERG, dump(k.current_process().cmdline))
        end

        table.remove(result, 1)
        result.n = result.n - 1
    end

    if coroutine.status(self.coro) == "dead" then
        if k.cmdline.log_process_deaths then
            k.printk(k.L_DEBUG, "thread died")
        end
        return 1
    end

    -- the coroutine can return one of a couple of things:
    --  * the randomized "sysyield" string generated at runtime, indicating a
    --    forced yield, e.g.: "4b2cda328f92c82e34a8tj2bvksdp30fasd"
    --  * a number, to wait either for a signal or until that much time has
    --    elapsed.
    --  * nothing, to wait indefinitely for a signal
    -- The if/else chain here isn't ordered quite like that for speed reasons.
    if result[1] == sysyield_string then
        self.status = "y"
    elseif result.n == 0 then
        self.deadline = math.huge
        self.status = "w"
    elseif type(result[1]) == "number" then
        self.deadline = computer.uptime() + result[1]
        self.status = "w"
    else
        self.deadline = math.huge
        self.status = "w"
    end

    -- self.deadline = math.min(self.deadline, 5)

    -- yes, we did resume the thread
    return true
end

-- Now for the actual thread implementation.
  -- A thread can have a few different states:
  --  * [r]unning
  --  * [w]aiting (the thread is waiting for a signal, or for a timeout)
  --  * [s]topped (got SIGSTOP)
  --  * [y]ielded (forcibly pre-empted)
  -- Each thread maintains a queue of signals up to 256 items long.

function k.create_thread(f)
    checkArg(1, f, "function")
    return setmetatable({
        coro = coroutine.create(f),
        queue = {},
        status = "w",
        deadline = 0
    }, {__index=thread})
end

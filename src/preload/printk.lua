--#ifdef INIT_SCREEN

k.L_EMERG   = 0
k.L_ALERT   = 1
k.L_CRIT    = 2
k.L_ERROR   = 3
k.L_WARNING = 4
k.L_NOTICE  = 5
k.L_INFO    = 6
k.L_DEBUG   = 7
k.cmdline.loglevel = tonumber(k.cmdline.loglevel) or 8

local reverse = {}
for name,v in pairs(k) do
    if name:sub(1,2) == "L_" then
        reverse[v] = name:sub(3)
    end
end



function k.printk(level, fmt, ...)
    local message = string.format("[%08.02f] %s: ", computer.uptime() - k.boottime, reverse[level]) .. string.format(fmt, ...)

    if level <= k.cmdline.loglevel then
        k.printf("%s\n", message)
    else
        k.debug(message .. "\n")
    end
end
k.printk(k.L_INFO, "preload")


local pullSignal = computer.pullSignal
function k.panic(reason)
    k.printk(k.L_EMERG, "Kernel Panic")
    local lines = split(reason, "\n")
    k.printk(k.L_EMERG, "Reason: %s", lines[1])
    local i
    for i = 2,#lines,1 do
        k.printf(k.L_EMERG, lines[i])
    end
    k.printk(k.L_EMERG, "#### stack traceback ####")
    for line in debug.traceback():gmatch("[^\n]+") do
        if line ~= "stack traceback:" then
            k.printk(k.L_EMERG, line)
        end
    end
  
    k.printk(k.L_EMERG, "#### end traceback ####")
    k.hlt()
end

error = k.panic

--#endif

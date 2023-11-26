function k.stopProcesses(signal)
    checkArg(1, signal, "string")
    for pid, proc in pairs(k.get_process()) do
        table.insert(k.get_process(pid).sigqueue, signal)
    end
end

provider.files.signals = {
    data = function() return "" end,
    ioctl = function(meth, ...)
        local args = table.pack(...)
        if meth == "shutdown" then
            k.stopProcesses("SIGTERM")
            computer.shutdown(false)
        elseif meth == "reboot" then
            k.stopProcesses("SIGTERM")
            computer.shutdown(true)
        end
    end
}

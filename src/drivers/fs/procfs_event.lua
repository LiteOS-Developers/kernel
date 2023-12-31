provider.files.events = {
    data = function() return "" end,
    ioctl = function(method, sig, a, ...)
        if method == "register" then
            local proc = k.current_process()

            local id = k.event.listen(sig, a)
            proc.handlers[id] = id
            return id
        elseif method == "deregister" then
            local proc = k.current_process()

            if not proc.handlers[sig] then
            return nil, k.errno.EINVAL
            end

            k.event.cancleListener(sig, proc.handlers[sig])
            proc.handlers[sig] = nil
            return true
        elseif method == "push" then
            return k.pushSignal(sig, a, ...)
        elseif method == "send" then
            checkArg(2, sig, "number")
            checkArg(3, a, "string")

            local proc = k.get_process(sig)
            local current = k.current_process()

            if not proc then
                return nil, k.errno.EINVAL
            end

            if current.euid ~= proc.uid and current.egid ~= proc.gid and current.euid ~= 0 then
                return nil, k.errno.EPERM
            end

            proc.queue[#proc.queue+1] = table.pack(a, ...)
            return true

        else
            return nil, k.errno.ENOTTY
        end
    end
}

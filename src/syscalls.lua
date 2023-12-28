
--#define SYSCALLS
k.printk(k.L_INFO, "syscalls")
k.syscalls = {}

function k.perform_system_call(call, ...)
    checkArg(1, call, "string")
    if not k.syscalls[call] then
        return nil, k.errno.ENOSYS
    end
    local result = table.pack(xpcall(k.syscalls[call], debug.traceback, ...))
    if not result[1] then
        local lines = split(result[2], "\n")
        k.printf("Error during syscall %s: %s\n", call, lines[1])
        for i = 2,#lines,1 do
            k.printf("%s\n", lines[i])
        end
        k.printf("\n")
        k.printf("\nOS in crash state. Stopping executing...\n")
        k.hlt()
    end
    return table.unpack(result, result[1] and 2 or 1, result.n)
end

function k.register_syscall(call, f)
    checkArg(1, call, "string")
    checkArg(2, f, "function")
    k.syscalls[call] = f
end

function k.syscalls.group(gid)
    checkArg(1, gid, "string")
    return k.groups[gid]
end

function k.syscalls.user(uid)
    checkArg(1, uid, "string")
    return k.users[uid]
end

function k.syscalls.geteuid()
    local cur = k.current_process()
    return cur and cur.euid or 0
end

function k.syscalls.getegid()
    local cur = k.current_process()
    return cur and cur.egid or 0
end

k.syscalls.mount = k.mount

function k.syscalls.exit(status)
    checkArg(1, status, "number")
    local current = k.current_process()
    current.status = status
    current.threads = {}
    current.thread_count = 0
    current.is_dead = true
    current.env.coroutine.yield(0.5)
end

function k.syscalls.getSession(sid)
    checkArg(1, sid, "number", "nil")
    if sid == nil then
        sid = k.current_process().sid
    end
    local sess
    if sid ~= 0 then
        sess = k.sessions[sid]
    end
    if not sess then
        sid = k.user.auth()
    end
    local user = sess and sess or k.sessions[k.current_process().sid]
    return user
end

function k.syscalls.name()
    return k.hostname
end

function k.syscalls.fork(f)
    checkArg(1, f, "function")
    local thread = k.create_thread(f)
    local proc = k.get_process(k.add_process())
    proc:addThread(thread)
    return proc.pid
end

function k.syscalls.wait(pid, nohang, untraced)
    checkArg(1, pid, "number")
    checkArg(2, nohang, "boolean", "nil")
    checkArg(3, untraced, "boolean", "nil")

    if not k.get_process(pid) then
        return nil, k.errno.ESRCH
    end

    if k.get_process(pid).ppid ~= cur_proc().pid then
        return nil, k.errno.ECHILD
    end
    
    local proc = k.get_process(pid)
    local cur = cur_proc()
    repeat
        if proc.stopped and untraced then
            return "stopped", proc.status
        end
    
        if not nohang then cur.env.coroutine.yield(0) end
    until proc.is_dead or nohang

    local process = k.get_process(pid)
    local reason, status = process.reason, process.status or 0

    if k.cmdline.log_process_deaths then
        printk(k.L_DEBUG, "process died: %d, %s, %d", pid, reason, status or 0)
    end
    k.remove_process(pid)

    return reason, status
end

function k.syscalls.kill(pid, name)
    checkArg(1, pid, "number")
    checkArg(2, name, "string")

    local current = k.current_process()

    local pids
    if pid > 0 then
        pids = {pid}

    elseif pid == 0 then
        pids = k.pgroup_pids(current.pgid)

    elseif pid == -1 then
        pids = k.get_pids()

    elseif pid < -1 then
        if not k.is_pgroup(-pid) then
            return nil, k.errno.ESRCH
        end

        pids = k.pgroup_pids(-pid)
    end

    if valid_signals[name] == nil and name ~= "SIGEXIST" then
        return nil, k.errno.EINVAL
    end

    local signaled = 0

    for i=1, #pids, 1 do
        local proc = k.get_process(pids[i])

        if (not proc) and #pids == 1 then
            return nil, k.errno.ESRCH
        else
            if current.uid == 0 or current.euid == 0 or current.uid == proc.uid or
                current.euid == proc.uid or current.uid == proc.suid or
                current.euid == proc.suid then

                signaled = signaled + 1

                if name ~= "SIGEXIST" then
                    table.insert(proc.sigqueue, name)
                end
            end
        end
    end

    if signaled == 0 then
        return nil, k.errno.EPERM
    end

    return true
end

function k.syscalls.running(pid)
    checkArg(1,pid,"number")
    if not k.get_process(pid) then return false end
    return not k.get_process(pid).is_dead
end

function k.syscalls.write(fd, buf)
    checkArg(1, fd, "number")
    checkArg(2, buf, "string")
    return k.write(fd, buf)
end
function k.syscalls.read(fd, c)
    checkArg(1, fd, "table")
    checkArg(2, c, "number", "string")
    return k.read(fd, c)
end
function k.syscalls.seek(fd, off, whe)
    checkArg(1, fd, "table")
    checkArg(2, off, "number")
    checkArg(3, whe, "string")
    return k.seek(fd, off, whe)
end
function k.syscalls.close(fd)
    checkArg(1, fd, "table")
    return k.close(fd)
end
function k.syscalls.open(path, mode)
    checkArg(1, path, "string")
    checkArg(2, mode, "string", "nil")
    local h, e = k.open(path, mode or "r")
    return h, e
end
function k.syscalls.makeDirectory(path)
    checkArg(1, path, "string")
    return k.mkDir(path)
end
function k.syscalls.spaceUsed(path)
    checkArg(1, path, "string")
    return k.du(path).used
end
function k.syscalls.exists(path)
    checkArg(1, path, "string")
    local stat = k.stat(path)
    if not stat then return false end
    return stat.mode & 0xF000 ~= 0
end

function k.syscalls.isReadOnly(path)
    checkArg(1, path, "string")
    assert(false, "Not Implemented")
end
function k.syscalls.spaceTotal(path)
    checkArg(1, path, "string")
    return k.du(path).total
end
function k.syscalls.isDirectory(path)
    checkArg(1, path, "string")
    local stat = k.stat(path)
    if not stat then return false end
    return stat.mode & k.perm.FS_DIR ~= 0
end
function k.syscalls.rename(from, to)
    checkArg(1, from, "string")
    checkArg(2, to, "string")
    return k.move(from, to)
end
function k.syscalls.list(path)
    checkArg(1, path, "string")
    return k.list(path)
end
function k.syscalls.lastModified(path)
    checkArg(1, path, "string")
    return k.stat(path).mtime
end

k.syscalls.stat = k.stat

function k.syscalls.getLabel(path)
    checkArg(1, path, "string")
    return k.du(path).label
end
function k.syscalls.remove(path)
    checkArg(1, path, "string")
    return k.remove(path)
end
function k.syscalls.size(path)
    checkArg(1, path, "string")
    return k.stat(path).size
end

function k.syscalls.getpid()
    return k.current_process().pid
end

local default_proc = { uid = 0, gid = 0 }
local function cur_proc()
    return k.current_process() or default_proc
end

k.syscalls.proc = cur_proc

function k.syscalls.pstat(pid)
    return k.get_process(pid) or {}
end

function k.syscalls.execve(path, args, env)
    checkArg(1, path, "string")
    checkArg(2, args, "table")
    checkArg(3, env, "table", "nil")
    args[0] = args[0] or path
    local current = k.current_process()
    
    local stat = k.stat(path)
    if not k.process_has_permission(cur_proc(), stat or {}, "x") then
        k.printk(k.L_WARNING, "No Permission for %s", path)
        return nil, k.errno.EACCES
    end
    
    local exec, err = k.load_executable(path, current.env)
    if not exec then
        k.printk(k.L_WARNING, "ERR %s: %s", path, dump(err))
        return nil, err
    end
    
    if (stat.mode & k.perm.FS_SETUID) ~= 0 then
        current.euid = stat.uid
        current.suid = stat.uid
    end

    if (stat.mode & k.perm.FS_SETGID) ~= 0 then
        current.egid = stat.egid
        current.sgid = stat.egid
    end

    current.threads = {}
    -- current.thread_count = 0
    current.environ = env or current.environ
    current.cmdline = args

    local thread = k.create_thread(function()
        local v = exec(args)
        return v
    end)
    k.current_process():addThread(thread)
    return true
end
--#ifdef ENABLE_SYSCALL_MKDEV
function k.syscalls.mkdev(name, calls)
    checkArg(1, name, "string")
    checkArg(2, calls, "table", "nil")

    if type(calls) == "nil" then
        local stat = k.stat("/dev/" .. name)
        if not k.process_has_permission(cur_proc(), stat, "x") then
            return nil, k.errno.EPERM
        end
        k.devfs.unregister_device(name)
        return true
    end
    local stat = k.stat("/dev")
    if not k.process_has_permission(cur_proc(), stat, "x") then
        return nil, k.errno.EPERM
    end
    k.debug(string.format("%s %s\n", name, dump(calls)))
    k.devfs.register_device(name, calls)
    return true
end
--#endif
function k.syscalls.mknod(path, type_)
    checkArg(1, path, "string")
    checkArg(2, type_, "string")
    checkArg(3, addr, "string", "nil")

    local stat = k.stat(path)
    if stat then return nil, k.errno.EEXIST end
    if path:sub(1, ("/dev/"):len()) ~= "/dev/" then return nil, k.errno.EINVAL end

    local stat = k.stat("/dev")
    if not k.process_has_permission(cur_proc(), stat, "w") then
        return nil, k.errno.EPERM
    end

    if not k.devfs.types[type_] then
        k.printk(k.L_EMERG, "Cannot register device '%s' with type '%s': TypeNotRegistered", path, type_)
        return nil, k.errno.ENOTSUP
    end
    k.devfs.register_device(path:sub(5), k.devfs.types[type_]())
    return true
end


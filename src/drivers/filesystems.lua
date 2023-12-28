
k.printk(k.L_INFO, "drivers/filesystem")

k.fstypes = {}

k.perm = {
    OWN_R = 256,
    OWN_W = 128,
    OWN_X = 64,

    G_R = 32,
    G_W = 16,
    G_X = 8,

    O_R = 4,
    O_W = 2,
    O_X = 1,

    FS_FIFO = 0x1000,
    FS_CHRDEV = 0x2000,
    FS_DIR = 0x4000,
    FS_BLKDEV = 0x6000,
    FS_FILE = 0x8000,
    FS_SYMLINK = 0xA000,
    FS_SOCKET = 0xC000,

    FS_SETUID = 0x0800, -- setuid bit
    FS_SETGID = 0x0400, -- setgid bit
    FS_STICKY = 0x0200, -- sticky bit

}


function k.register_fstype(name, recognizer)
    checkArg(1, name, "string")
    checkArg(2, recognizer, "function")

    if k.fstypes[name] then
        k.panic("attempted to double-register fstype " .. name)
    end
    k.fstypes[name] = recognizer
end

function k.split_path(path)
    checkArg(1, path, "string")

    local segments = {}
    for piece in path:gmatch("[^/\\]+") do
        if piece == ".." then
            segments[#segments] = nil

        elseif piece ~= "." then
            segments[#segments+1] = piece
        end
    end

    return segments
end

local order = {
    0x001,
    0x002,
    0x004,
    0x008,
    0x010,
    0x020,
    0x040,
    0x080,
    0x100,
}

function k.has_permission(ogo, mode, perm)
    checkArg(1, ogo, "number")
    checkArg(2, mode, "number")
    checkArg(3, perm, "string")

    local val_check = 0

    local base_index = ogo * 3
    for c in perm:gmatch(".") do
        if c == "r" then
            val_check = (val_check | order[base_index])
        elseif c == "w" then
            val_check = (val_check | order[base_index - 1])
        elseif c == "x" then
            val_check = (val_check | order[base_index - 2])
        end
    end

    return (mode & val_check) == val_check
end

function k.process_has_permission(proc, stat, perm)
    checkArg(1, proc, "table")
    checkArg(2, stat, "table")
    checkArg(3, perm, "string")

    -- grand root group full perms
    -- used by system to access files without attribute file or with broken
    if proc.gid == 0 then return true end
    
    if proc.euid == 0 and perm ~= "x" then return true end
    
    local ogo = (proc.euid == stat.uid and 3) or (proc.egid == stat.gid and 2) or 1
    return k.has_permission(ogo, stat.mode, perm)
end

k.printk(k.L_INFO, "lib/romfs")
--#define ROMFS
k.romfs = {}

function k.romfs:content(file)
    return self.files[file].content
end

function k.romfs.open(romName)
    local handle, err = bootfs.open(romName)
    if not handle then return nil, err end
    local files = {}
    while true do
        local nameLength = string.unpack("<B", bootfs.read(handle, 1))
        local name = bootfs.read(handle, nameLength)
        if name == "TRAILER!!!" then break end
        local size = string.unpack("<H", bootfs.read(handle, 2))
        local mode = bootfs.read(handle, 1)
        local content = ""
        local buf
        local sizeLeft = size
        repeat
            buf = bootfs.read(handle, sizeLeft)
            if buf ~= nil then sizeLeft = sizeLeft - buf:len() end
            content = content .. (buf or "")
        until not buf or sizeLeft <= 0
        local file = {
            name = name,
            size = size,
            mode = mode,
            content = content,
        }
        files[name] = file
    end
    bootfs.close(handle)
    return setmetatable({
        files = files,
        rom = romName
    }, {__index = k.romfs})
end

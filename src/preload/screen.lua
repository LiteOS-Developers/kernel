--#define INIT_SCREEN

local screen = component.list("screen", true)()
local gpu = screen and component.list("gpu", true)()
k.devices = {}
if gpu then 
    gpu = component.proxy(gpu)

    if gpu then
        if not gpu.getScreen() then 
            gpu.bind(screen)
        end
        local w, h = gpu.getResolution()
        k.cursor:init(1, 1, w, h)
        gpu.setResolution(w, h)
        gpu.setForeground(0xFFFFFF)
        gpu.setBackground(0x000000)
        gpu.fill(1, 1, w, h, " ")
        k.devices.screen = component.proxy(screen)
    end
    gpu.setPaletteColor(0, 0x000000)
    gpu.setPaletteColor(1, 0xff0000)
    gpu.setPaletteColor(2, 0x00ff00)
    gpu.setPaletteColor(3, 0xffff00)
    gpu.setPaletteColor(4, 0x0000ff)
    gpu.setPaletteColor(5, 0xf653a6)
    gpu.setPaletteColor(6, 0x00ffff)
    gpu.setPaletteColor(7, 0xffffff)

    gpu.setPaletteColor(9, 0x000000)
end

function k.setText(x, y, text)
    local w, h = gpu.getResolution()
    gpu.fill(x, y, w-x, 1, " ")
    gpu.set(x, y, text:sub(1, w-x))
end

k.printf = function(fmt, ...)
    local msg = string.format(fmt, ...)
    if gpu then
        local sw, sh = k.cursor.width, k.cursor.height
        local lines = split(msg, "\n")
        for idx, l in pairs(lines) do
            l = l:gsub("\t", "  ")
            -- lib.log_to_screen(dump(sh))
            gpu.set(k.cursor:getX(), k.cursor:getY(), l)
            if k.cursor:getY() == k.cursor.height and idx < #lines and #lines >= 2 and msg:sub(-1, -1) == "\n" then
                gpu.copy(1, 2, sw, sh - 1, 0, -1)
                gpu.fill(1, sh, sw, 1, " ")
            end
            if idx < #lines then
                k.cursor:incy(1)
            end
        end
        if msg:sub(-1, -1) ~= "\n" then
            k.cursor:incx(string.len(lines[#lines]))
        elseif msg:sub(-1, -1) == "\n" then
            k.cursor:move(1)
            if k.cursor:getY() < k.cursor.height then   
                k.cursor:incy(1)
            elseif k.cursor:getY() == k.cursor.height then
                gpu.copy(1, 2, sw, sh - 1, 0, -1)
                gpu.fill(1, sh, sw, 1, " ")
            end
        end
    end
    --[[if gpu then
        local sw, sh = k.cursor.width, k.cursor.height
        local lines = split(msg, "\n")
        for linenr, line in ipairs(lines) do
            if linenr == #lines then
                if k.cursor:getY() == sh then
                    gpu.copy(1, 2, sw, sh - 1, 0, -1)
                    gpu.fill(1, sh, sw, 1, " ")
                end
            else
            end
            line = line:gsub("\t", "  ")
            gpu.set(k.cursor:getX(), k.cursor:getY(), l)
            if linenr < #lines  then
                k.cursor:incy(1)
            end
        end
    end]]--
    k.debug(msg)
end

k.getGPU = function() return gpu end
k.getScreen = function() return screen end
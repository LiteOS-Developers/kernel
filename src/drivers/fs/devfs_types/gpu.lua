local gpuprovider = {}
local mt = {
    __index = gpuprovider
}

function gpuprovider:setBackground(color, isPaletteIndex)
    checkArg(1, color, "number")
    checkArg(2, isPaletteIndex, "boolean")
    return table.unpack({self.comp.setBackground(color, isPaletteIndex)})
end
function gpuprovider:setForeground(color, isPaletteIndex)
    checkArg(1, color, "number")
    checkArg(2, isPaletteIndex, "boolean")
    return table.unpack({self.comp.setForeground(color, isPaletteIndex)})
end
function gpuprovider:getBackground()
    return table.unpack({self.comp.getBackground(color, isPaletteIndex)})
end
function gpuprovider:getForeground()
    return table.unpack({self.comp.getForeground()})
end
function gpuprovider:setPaletteColor(isPaletteIndex, color)
    checkArg(1, isPaletteIndex, "boolean")
    checkArg(2, color, "number")
    return table.unpack({self.comp.setForeground(color, isPaletteIndex)})
end
function gpuprovider:getPaletteColor()
    return table.unpack({self.comp.getBackground()})
end
function gpuprovider:maxDepth()
    return self.comp.maxDepth()
end
function gpuprovider:getDepth()
    return self.comp.getDepth()
end
function gpuprovider:setDepth(value)
    checkArg(1, value, "number")
    return self.comp.setDepth(value)
end
function gpuprovider:maxResolution()
    return table.unpack({self.comp.maxResolution()})
end
function gpuprovider:getResolution()
    return table.unpack({self.comp.getResolution()})
end
function gpuprovider:getViewport()
    return table.unpack({self.comp.getViewport()})
end
function gpuprovider:setResolution(w, h)
    checkArg(1, w, "number")
    checkArg(2, h, "number")
    return table.unpack({self.comp.setResolution(w, h)})
end
function gpuprovider:setViewport(w, h)
    checkArg(1, w, "number")
    checkArg(2, h, "number")
    return table.unpack({self.comp.setViewport(w, h)})
end
function gpuprovider:get(x, y)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    return table.unpack({self.comp.get(x, y)})
end
function gpuprovider:set(x, y, value, vertical)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    checkArg(3, value, "string")
    checkArg(4, vertical, "boolean")
    return table.unpack({self.comp.set(x, y, value, vertical)})
end
function gpuprovider:copy(x, y, w, h, tx, ty)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    checkArg(3, w, "number")
    checkArg(4, h, "number")
    checkArg(5, tx, "number")
    checkArg(6, ty, "number")
    return table.unpack({self.comp.copy(x, y, w, h, tx, ty)})
end
function gpuprovider:fill(x, y, w, h, chr)
    checkArg(1, x, "number")
    checkArg(2, y, "number")
    checkArg(3, w, "number")
    checkArg(4, h, "number")
    checkArg(5, chr, "string")
    return table.unpack({self.comp.fill(x, y, w, h, chr)})
end

function gpuprovider:getActiveBuffer()
    return self.comp.getActiveBuffer()
end
function gpuprovider:setActiveBuffer(idx)
    checkArg(1, idx, "number")
    return self.comp.setActiveBuffer(idx)
end
function gpuprovider:buffers()
    return self.comp.buffers(idx)
end
function gpuprovider:allocateBuffer(w, h)
    checkArg(1, w, "number", "nil")
    checkArg(2, h, "number", "nil")
    return table.unpack({self.comp.allocateBuffer(w, h)})
end
function gpuprovider:freeBuffer(idx)
    checkArg(1, idx, "number", "nil")
    return table.unpack({self.comp.freeBuffer(idx)})
end
function gpuprovider:getBufferSize(idx)
    checkArg(1, idx, "number", "nil")
    return table.unpack({self.comp.getBufferSize(idx)})
end
function gpuprovider:freeAllBuffers()
    return self.comp.freeAllBuffers()
end
function gpuprovider:totalMemory()
    return self.comp.totalMemory()
end
function gpuprovider:freeMemory()
    return self.comp.freeMemory()
end

function gpuprovider:bitblt(dst, col, row, w, h, src, fromCol, fromRow)
    checkArg(1, dst, "number", "nil")
    checkArg(2, col, "number", "nil")
    checkArg(3, row, "number", "nil")
    checkArg(4, w, "number", "nil")
    checkArg(5, h, "number", "nil")
    checkArg(6, src, "number", "nil")
    checkArg(7, fromCol, "number", "nil")
    checkArg(8, fromRow, "number", "nil")
    self.comp.bitblt(dst, col, row, w, h, src, fromCol, fromRow)
end


k.devfs.register_device_type(5, 0, "c", function()
    local gpu = component.list("gpu")()
    return setmetatable({comp = gpu}, mt)
end)
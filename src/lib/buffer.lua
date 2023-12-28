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

k.printk(k.L_INFO, "lib/buffer")
--#define LIB_BUFFER


k.buffer = {}
local metatable = {
    __index = k.buffer
}

function k.buffer.new(mode, stream)
    local result = {
        closed = false,
        mode = {},
        stream = stream,
        bufferSize = math.max(512, math.min(4 * 1024, computer.freeMemory() / 8)),
        readTimeout = math.huge,
        bufferRead = "",
        bufferWrite = "",
    }
    mode = mode or "r"
    for i = 1, unicode.len(mode) do
        result.mode[unicode.sub(mode, i, i)] = true
    end
    -- stream.close = setmetatable({close = stream.close,parent = result},{__call = k.buffer.close})
    return setmetatable(result, metatable)
end


local function readChunk(self)
    -- error(tostring(math.max(1,self.bufferSize)))
    local result, reason = self.stream:read(math.max(1,self.bufferSize))
    if result then
        self.bufferRead = self.bufferRead .. result
        return self
    else -- error or eof
        return result, reason
    end
end

function k.buffer:close()
    if self.mode.w or self.mode.a then
        self:flush()
    end
    self.bufferRead = ""
    self.closed = true
    if self.stream.close then
        return self.stream:close()
    end
    return true
  end

function k.buffer:flush()
    if self.mode.w or self.mode.a then
        local tmp = self.bufferWrite
        self.bufferWrite = ""
        local result, reason = self.stream:write(tmp)
        if not result then
            return nil, reason or k.errno.EBADF
        end
    end
  
    return self
end

function k.buffer:lines()
    if self.closed then
        return nil, k.errno.EBADFD
    end
    if not self.mode.r then
        return nil, k.errno.EBADFD
    end
    self:flush()
    
    return function()
        return self:read("l")
    end
end

function k.buffer:read(v)
    if not self.mode.r then
        return nil, k.errno.EBADFD
    end
  
    if self.mode.w or self.mode.a then
        self:flush()
    end
    
    if v == "l" then
        return self:readLine(true)
    else
        return self.stream:read(v)
    end
end

function k.buffer:readLine(chop)
    if self.closed then
        return nil, k.errno.EBADFD
    end
    if not self.mode.r then
        return nil, k.errno.EBADFD
    end
    self:flush()
    local start = 1
    if self.bufferMode == "full" or self.bufferMode == "line" then
        local nl
        if self.bufferRead:len() == 0 then
            self.bufferRead = self.stream:read()
        end
        if not self.bufferRead then
            self.bufferRead = ""
            return nil
        end
        repeat
            nl = self.bufferRead:find("[\r\n]", 0)
            if nl == nil then
                local result = self.stream:read()
                if not result then nl = self.bufferRead:len()
                else 
                    self.bufferRead = self.bufferRead .. result
                end
            end
        until nl
        local nextLineStart = nl + 1
        if chop then
            nl = nl - 1

        end
        buf = self.bufferRead:sub(1, nl)
        self.bufferRead = self.bufferRead:sub(nl + 2)
        self.stream:seek(nextLineStart, "set")
        return buf
    end
end

function k.buffer:seek(offset, whence)
    checkArg(1, offset, "number")
    assert(math.floor(offset) == offset, "bad argument #1 (not an integer)")

    whence = tostring(whence or "set")
    assert(whence == "set" or whence == "cur" or whence == "end",
    "bad argument #2 (set, cur or end expected, got " .. whence .. ")")

    if self.mode.w or self.mode.a then
        self:flush()
    elseif whence == "cur" then
        offset = offset - #self.bufferRead
    end
    local result, reason = self.stream:seek(offset, whence)
    if result then
        self.bufferRead = ""
        return result
    else
        return nil, reason
    end
end

function k.buffer:write_buffered(data)
    local result, reason
    if self.bufferMode == "full" then
        if self.bufferSize - #self.bufferWrite < #data then
            result, reason = self:flush()
            if not result then return nil, reason end
        end
        if #data > self.bufferSize then
            self.stream:write(data)
        else
            self.bufferWrite = self.bufferWrite .. data
            result = self
        end
    else
        local l
        repeat
            local idx = data:find("\n", (l or 0) + 1, true)
            if idx then
                l = idx
            end
        until not idx
        if l or #data > self.bufferSize then
            result, reason = self:flush()
            if not result then return nil, reason end
        end
        if l then
            result, reason = self.stream:write(data:sub(1, l))
            if not result then return nil, reason end
            data = data:sub(l+1)
        end
        if #data > self.bufferSize then
            result, reason = self.stream:write(data)
            result = self
        else
            self.bufferWrite = self.bufferWrite .. data
            result = self
        end
    end
    return result, reason
end

function k.buffer:setvbuf(mode, size)
    mode = mode or self.bufferMode
    size = size or self.bufferSize
  
    assert(mode == "no" or mode == "full" or mode == "line",
      "bad argument #1 (no, full or line expected, got " .. tostring(mode) .. ")")
    assert(mode == "no" or type(size) == "number",
      "bad argument #2 (number expected, got " .. type(size) .. ")")
  
    self.bufferMode = mode
    self.bufferSize = size
  
    return self.bufferMode, self.bufferSize
end

function k.buffer:writelines(...)
    for k, line in pairs(table.pack(...)) do
        if k ~= "n" then
            self:write(tostring(line) .. "\n")
        end
    end
    
end

function k.buffer:write(...)
    if self.closed then
        return nil, "Buffer already closed"
    end 
    if not self.mode.w and not self.mode.a then
        return nil, "Buffer not opened for Writing"
    end
    local args = table.pack(...)
    for i = 1, args.n do
        if type(args[i]) == "number" then
            args[i] = tostring(args[i])
        end
        checkArg(i, args[i], "string")
    end

    for i = 1, args.n do
        local arg = args[i]
        local result, reason
        arg = arg:gsub("\t", "    ")

        if self.bufferMode == "no" then
            result, reason = self.stream:write(arg)
        else
            result, reason = self:write_buffered(arg)
        end
        if not result then
            return nil, reason
        end
    end
    return self
end
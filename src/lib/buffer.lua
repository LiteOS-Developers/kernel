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
    local data = ""
    local buf, e
    repeat
        local buf, e = self.stream:read(math.max(1, self.bufferSize))
        if not buf and e then
            return nil, e
        end
        data = data .. (buf or "")
    until buf
    local lines = {}
    for _, l in data:gmatch("[^\n]+") do
        table.insert(lines, l)
    end
    local index = 0
    return setmetatable(lines, {
        __call = function()
            index = index + 1
            return lines[index]
        end
    })
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
        return self.stream:read()
    end
end

function k.buffer:readLine(chop)
    if self.closed then
        return nil, k.errno.EBADFD
    end
    if not self.mode.r then
        return nil, k.errno.EBADFD
    end
    local start = 1
    if self.mode == "full" or self.mode == "line" then
        while true do
            local buf = self.bufferRead
            local i = buf:find("[\r\n]", start)
            local c = i and buf:sub(i,i)
            local is_cr = c == "\r"
            if i and (not is_cr or i < #buf) then
                local n = buf:sub(i+1,i+1)
                if is_cr and n == "\n" then
                    c = c .. n
                end
                local result = buf:sub(1, i - 1) .. (chop and "" or c)
                self.bufferRead = buf:sub(i + #c)
                return result
            else
                start = #self.bufferRead - (is_cr and 1 or 0)
                local result, reason = readChunk(self)
                if not result then
                    if reason then
                        return result, reason
                    else -- eof
                        result = #self.bufferRead > 0 and self.bufferRead or nil
                        self.bufferRead = ""
                        return result
                    end
                end
            end
        end 
    else
        local data = self.stream:read()
        return data:match("([^\n]+)")
    end
end

function k.buffer:seek(offset, whence)
    checkArg(1, offset, "number")
    assert(math.floor(offset) == offset, "bad argument #1 (not an integer)")

    tostring(whence or "cur")
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
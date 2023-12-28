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


k.cursor = {
    x = 0,
    y = 0,
    width = 0,
    height = 0
}

k.cursor.init = function(self, x, y, w, h)
    self.x = x
    self.y = y
    self.width = w
    self.height = h
    return self
end

k.cursor.getX = function(self)
    return self.x
end
k.cursor.getY = function(self)
    return self.y
end
k.cursor.getWidth = function(self)
    return self.width
end
k.cursor.getHeight = function(self)
    return self.height
end

k.cursor.move = function(self, x, y)
    if x then self.x = x end
    if y then self.y = y end
end
k.cursor.incx = function(self, v)
    self.x = self.x + v
end
k.cursor.incy = function(self, v)
    self.y = self.y + v
end

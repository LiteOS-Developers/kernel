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

k.printk(k.L_INFO, "package")

k.package = {
    searchPaths = {
        "/lib/?.lua",
        "/lib/?/init.lua",
        "/lib/?/?.lua",
        "/usr/lib/?.lua",
        "/usr/lib/?/init.lua",
        "/usr/lib/?/?.lua",
    },
    loaded = {}
}

k.package.load = function(name)
    if #k.package.searchPaths == 0 then return nil end
    if k.package.loaded[name] ~= nil then return k.package.loaded[name] end
    for _, path in ipairs(k.package.searchPaths) do
        path = path:gsub("?", name)
        local stat = k.stat(path)
        if stat and stat.mode & k.perm.FS_FILE then
            local data = ""
            local chunk
            local handle, e = k.open(path, "r")
            if not handle then return nil, e end
            repeat
                chunk = k.read(handle, 128)
                data = data .. (chunk or "")
            until not chunk
            -- error("!")
            k.close(handle)
            local l, err = load(data, "=" .. path, "bt")
            if not l then
            end
            k.package.loaded[name] = l()
            return k.package.loaded[name]
        end
    end
    return nil
end

k.require = function(name)
    return k.package.load(name)
end

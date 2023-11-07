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

k.printk(k.L_INFO, "user/auth")
k.user = {}
do
    k.groups = {}
    local groups = k.readfile("/etc/group")
    for _, line in ipairs(split(groups, "\n")) do
        local data = split(line, ":")
        local g = {}
        g.name = data[1]
        g.gid = data[2]
        local users = data[3]:gsub("\r", "")
        users = split(users, ",")
        g.users = users
        k.groups[g.gid] = deepcopy(g)
    end
end
do
    k.users = {}
    local users = k.readfile("/etc/passwd")
    for _, line in ipairs(split(users, "\n")) do
        local user = {}
        local data = split(line, ":")
        user.name = data[1]
        user.hashpw = data[2]
        user.uid = data[3]
        user.primGid = data[4]
        user.home = data[5]
        user.shell = data[6]
        k.users[user.uid] = user
    end
end
k.sessions = {}
local sha3 = k.require("sha3")
k.hostname = k.readfile("/etc/hostname")

function k.user.groups(username)
    local ugroup = {}
    for _, g in pairs(k.groups) do
        if table.contains(g.users, username) then
            ugroup[#ugroup+1] = g
            break
        end
    end
    return ugroup
end

function k.user.match(username, password)
    for uid, user in pairs(k.users) do
        if password == user.hashpw and username == user.name then
            user.groups = k.user.groups(username)
            return true, user
        end
    end
    return false, nil
end

function k.user.auth()
    while true do
        k.printf("%s login: ", k.hostname)
        local username = k.io.stdin:read()
        k.printf("Password: ")
        local password = tohex(sha3.sha512(k.getpass()))
        local match, user = k.user.match(username, password)
        if match then
            local sid
            repeat
                sid = math.random(1, 64*1024)
            until not k.sessions[sid]
            k.sessions[sid] = user
            k.current_process().sid = sid
            return sid
        else
            k.printf("Bad Login\n")
        end
    end
end


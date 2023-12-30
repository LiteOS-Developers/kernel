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

--#define KERNEL

local k = {}
k.slowDown = 0.5
k.boottime =  computer.uptime()
k.hlt = function()
    k.debug("Called hlt! Computer stopped execution")
    while true do computer.pullSignal() end
end
--#include "libstd.lua"
--#include "preload/main.lua"
--#include "modules.lua"
--#include "errno.lua"
--#include "event.lua"
--#include "uuid.lua"
--#include "fd.lua"
--#include "drivers/main.lua"
--#include "lib/main.lua"
--#include "init/main.lua"
--#include "scheduler/main.lua"
--#include "package.lua"
--#include "syscalls.lua"
--#include "user/main.lua"

k.scheduler_loop()
k.panic("Kernel Stopped!")
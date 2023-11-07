--#define COMPONENT
k.printk(k.L_INFO, "drivers/vcomponent")

k.component = {
    components = {},
    names = {},
    overwrites = {}
}
local native = component

local function tableMerge(t1, t2)
    local result = t1
    for k, v in pairs(t2) do result[k] = v end
    return result
end

k.component.getName = function(addr)
    return k.component.names[addr] or addr
end

k.component.setName = function(addr, value)
    checkArg(1, addr, "string")
    checkArg(2, value, "string")
    k.component.names[addr] = value
end

k.component.hasMethod = function(addr, method)
    checkArg(1, addr, "string")
    checkArg(2, method, "string")
    if k.component.components[addr] ~= nil then
        return k.component.components[addr].api[method] ~= nil
    end
    if k.component.overwrites[native.type(addr)] ~= nil then
        if k.component.overwrites[native.type(addr)][method] ~= nil then return true end
    end
    return native.methods(addr)[method] ~= nil
end

k.component.overwrite = function(addr, name, func)
    if not k.component.isVirtual(addr) then
        if not k.component.overwrites[addr] then k.component.overwrites[addr] = {} end
        k.component.overwrites[addr][name] = func
    end
end

k.component.invoke = function(addr, method, ...)
    checkArg(1, addr, "string")
    checkArg(2, method, "string")
    if k.component.components[addr] ~= nil then
        if k.component.components[addr].api[method] ~= nil then
            return k.component.components[addr].api[method](...)
        end
    end
    if k.component.overwrites[addr] ~= nil then
        if k.component.overwrites[addr][method] ~= nil then
            return k.component.overwrites[addr][method](...)
        end
    end
    return native.invoke(addr, method, ...)
end

k.component.list = function(filter, exact)
    checkArg(1, filter, "string", "nil")
    checkArg(2, exact, "boolean", "nil")
    exact = exact or false
    return native.list(filter, exact)
end

k.component.proxy = function(addr)
    if table.contains(k.component.components, addr ) then
        return k.component.components[addr].api
    end
    local api = native.proxy(addr) 
    for n, f in pairs(k.component.overwrite) do
        api[n] = f
    end
    return api
end

k.component.type = function(addr)
    if table.contains(k.component.components, addr) then
        return k.component.components[addr].type_
    end
    return native.type(addr) 
end

k.component.register = function(addr, type_, calls)
    k.component.components[addr] = {
        type_=type,
        api=calls
    }
end

k.component.exists = function(addr)
    return component.proxy(addr) ~= nil or k.component.isVirtual(addr)
end

k.component.isVirtual = function(addr)
    return k.component.components[addr] ~= nil
end

do
    k.printk(k.L_INFO, "init/filesystem")
    k.printk(k.L_DEBUG, "Mounting RootFS")
    k.mount(computer.getBootAddress(), "/")
    --#ifdef DRV_DEVFS
    --#endif
    for addr, type in component.list("filesystem") do
        k.printk(k.L_DEBUG, "Mounting %s", addr:sub(1,3))
        k.mount(addr, "/mnt/" .. addr:sub(1,3))
    end
end
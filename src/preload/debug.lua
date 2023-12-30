local debugfd

function k.debug_init()
--#ifdef ENABLE_DEBUG 
    debugfd = bootfs.open("/debug.txt", "w")
--#endif 
end


function k.debug(str)
--#ifdef ENABLE_DEBUG 
    bootfs.write(debugfd, str)
--#endif 
end

--#ifdef ENABLE_DEBUG 
k.debug_init()
k.debug("Debug started!\n")
--#endif 

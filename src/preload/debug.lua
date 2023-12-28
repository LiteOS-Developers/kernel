local debugfd

function k.debug_init()
--#ifdef DEBUG_ENABLED 
    debugfd = bootfs.open("/debug.txt", "w")
--#endif 
end


function k.debug(str)
--#ifdef DEBUG_ENABLED 
    bootfs.write(debugfd, str)
--#endif 
end

--#ifdef DEBUG_ENABLED 
k.debug_init()
k.debug("Debug started!\n")
--#endif 

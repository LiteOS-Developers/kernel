local chardev = {}

function chardev.new(stream)
    checkArg(1, stream, "table")

    return setmetatable({
        stream = stream, type="chardev"
    }, {__index = chardev})
end

function chardev:open()
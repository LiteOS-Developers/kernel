import struct, os

class FileMode:
    default = b"-"
    executable = b"x"
    
class RomFS:
    def __init__(self, filename) -> None:
        self.file = open(filename, "wb")
    
    def addFile(self, name:bytes, mode:bytes, data:bytes):
        data = struct.pack(f"<B{len(name)}sH1s{len(data)}s", len(name), name, len(data), mode, data)
        self.file.write(data)

    def save(self):
        self.addFile(b"TRAILER!!!", b"h", b"\x00")
        self.file.close()
     
    @staticmethod   
    def listFiles(filename:str):
        with open(filename, "rb") as f:
            while True:
                namelen = struct.unpack("<B", f.read(1))[0]
                name = f.read(namelen).decode("utf-8")
                if name == "TRAILER!!!": break
                size = struct.unpack("<H", f.read(2))[0]
                mode = f.read(1).decode("utf-8")
                f.read(size)
                size /= 1024
                print(f"{size:.2f}k {name} ({mode})")
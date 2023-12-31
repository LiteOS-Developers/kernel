import tomllib, os, io
from preprocess import PreProcessor
from romfs import RomFS

BASEDIR =  os.path.join(os.path.dirname(os.path.abspath(__file__)), os.path.pardir)

CONFIG_PATH = os.path.join(BASEDIR, ".config")
BUILD_FILE = os.path.join(BASEDIR, "src", "main.lua")
OUTFILE = os.path.join(BASEDIR, "build", "boot", "kernel.lua")
MODDIR = os.path.join(BASEDIR, "build", "lib", "modules")

if not os.path.exists(CONFIG_PATH):
    # fallback build ?
    raise Exception("No Config")

# def getConfig():
with open(CONFIG_PATH, "rb") as f:
    data = tomllib.load(f)
    
modules = {
    "rootfs": [False, ""],
    "managedfs": [False, "src/drivers/fs/managed.lua"],
    "procfs": [False, "src/drivers/fs/procfs.lua"],
    "devfs": [False, "src/drivers/fs/devfs.lua"],
}

proc = PreProcessor(BUILD_FILE, OUTFILE, {})

for key, value in data.get("config", {}).items():
    proc.defines[key] = True if value == "y" else value

if data.get("enableModules") == "y":
    proc.defines["modules"] = True
    for device, value in data.get("modules", {}).items():
        if value == "n": 
            proc.defines["module_" + device] = True
        else:
            modules[device][0] = True

cwd = os.getcwd()
# print(proc.defines)
os.chdir(os.path.dirname(BUILD_FILE))
proc.process()

if data.get("enableModules") == "y":
    if not os.path.isdir(MODDIR):
        os.makedirs(MODDIR)

        
a = filter(lambda k: k[1][0], modules.items())
for module, files in list(a):
    filename = os.path.join(MODDIR, module)
    file = files[1]
    fs = RomFS(filename)
    print("[MOD] %s" % module)
    fname = os.path.join(BASEDIR, file)
    with open(fname, "r") as f:
        out = io.StringIO()
        proc = PreProcessor(f, out)
        proc.defines["module"] = True
        proc.process()
        fs.addFile(b"main.lua", b"-", out.getvalue().encode("utf-8"))
    fs.save()
os.chdir(cwd)

echo Building Sucata for Windows...

echo Building sucata-player.exe...
odin build src/ -out:sucata-player.exe -o:speed -extra-linker-flags:"/NODEFAULTLIB:ucrt.lib"

echo Done!


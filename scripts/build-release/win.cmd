echo Building Sucata for Windows...

echo Building sucata-player.exe...
odin build src/ -out:sucata-player.exe -o:speed -extra-linker-flags:"/VERBOSE:LIB" 2>&1

echo Done!


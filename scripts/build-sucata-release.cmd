echo Building Sucata for Windows...

echo Building sucata.exe...
odin build .

echo Building sucata-player.exe...
odin build ./src/player.odin -file -out:sucata-player.exe

mkdir release
mkdir release\windows

echo Copying files...
copy sucata.exe release\windows\
copy sucata-player.exe release\windows\
copy lua54.dll release\windows\
copy SDL3.dll release\windows\

echo Done!


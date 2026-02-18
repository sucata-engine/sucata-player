odin build .
odin build ./src/player.odin -file -out:sucata-player.exe

move /Y "sucata.exe" "C:\Users\gbrxb\sucata\"
move /Y "sucata-player.exe" "C:\Users\gbrxb\sucata\"

echo "Sucata builded!" 
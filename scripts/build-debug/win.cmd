echo Building Sucata for Windows...

echo Building sucata-player.exe...
odin build src/ -out:sucata-player.exe -debug -sanitize:address

echo Done!


$OdinRoot = odin root
$OdinShared = "$OdinRoot\shared"

Set-Location $OdinShared

Remove-Item -Recurse -Force -ErrorAction SilentlyContinue sokol
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue odin-http

$SokolOdinCommit = "974cb5a1c91e33f5ca8ccb09532d13770918af2c"

git clone https://github.com/floooh/sokol-odin.git
git -C sokol-odin checkout $SokolOdinCommit
Move-Item .\sokol-odin\sokol .
Remove-Item -Recurse -Force sokol-odin

Push-Location sokol
& .\build_clibs_windows.cmd
Pop-Location

git clone https://github.com/laytan/odin-http.git
Move-Item .\odin-http .\http
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue odin-http
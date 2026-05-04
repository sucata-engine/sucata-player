$OdinRoot = odin root
$OdinShared = "$OdinRoot\shared"

Set-Location $OdinShared

Remove-Item -Recurse -Force -ErrorAction SilentlyContinue sokol
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue odin-http

git clone https://github.com/floooh/sokol-odin.git
Move-Item .\sokol-odin\sokol .
Remove-Item -Recurse -Force sokol-odin

git clone https://github.com/laytan/odin-http.git
Move-Item .\odin-http\client .\http
Remove-Item -Recurse -Force odin-http
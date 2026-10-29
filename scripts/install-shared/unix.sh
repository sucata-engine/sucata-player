#!/usr/bin/env bash

set -e

ODIN_ROOT=$(odin root)
ODIN_SHARED="$ODIN_ROOT/shared"

cd $ODIN_SHARED

rm -rf sokol
rm -rf http

SOKOL_ODIN_COMMIT=49d76fd12201f33d16e3fbe78d2d508351507822

git clone https://github.com/floooh/sokol-odin.git
git -C sokol-odin checkout $SOKOL_ODIN_COMMIT
mv ./sokol-odin/sokol .
rm -rf sokol-odin

cd sokol
case "$(uname -s)" in
  Darwin)
    # arm64 Macs never ran macOS 10.13 (Apple Silicon starts at 11.0) — recent
    # Xcode SDKs reject that combo outright (breaks NSInteger/NSUInteger while
    # compiling sokol_gfx.c's Metal/Foundation includes). Bump the target the
    # script hardcodes so the arm64 build actually compiles.
    sed -i '' 's/MACOSX_DEPLOYMENT_TARGET=10.13/MACOSX_DEPLOYMENT_TARGET=11.0/g' build_clibs_macos.sh
    ./build_clibs_macos.sh
    ;;
  Linux)  ./build_clibs_linux.sh ;;
  *) echo "Unsupported OS for building sokol clibs: $(uname -s)" >&2; exit 1 ;;
esac
cd ..

if [ "$(uname -s)" = "Darwin" ]; then
  (
    cd "$ODIN_ROOT/vendor/stb/src"
    for f in stb_image stb_image_write stb_image_resize stb_truetype stb_rect_pack stb_vorbis stb_sprintf; do
      cc -arch "$(uname -m)" -c -O2 -fPIC "$f.c" -o "$f.o" -mmacosx-version-min=11.0
      rm -f "../lib/darwin/$f.a"
      ar rcs "../lib/darwin/$f.a" "$f.o"
      rm "$f.o"
    done
  )
fi

ODIN_ROOT="$ODIN_ROOT" sh "$ODIN_ROOT/vendor/miniaudio/src/build_miniaudio.sh"

git clone https://github.com/laytan/odin-http.git
mv ./odin-http ./http
rm -rf odin-http
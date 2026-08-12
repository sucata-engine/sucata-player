#!/usr/bin/env bash

set -e

ODIN_ROOT=$(odin root)
ODIN_SHARED="$ODIN_ROOT/shared"

cd $ODIN_SHARED

rm -rf sokol
rm -rf http

git clone https://github.com/floooh/sokol-odin.git
mv ./sokol-odin/sokol .
rm -rf sokol-odin

cd sokol
case "$(uname -s)" in
  Darwin) ./build_clibs_macos.sh ;;
  Linux)  ./build_clibs_linux.sh ;;
  *) echo "Unsupported OS for building sokol clibs: $(uname -s)" >&2; exit 1 ;;
esac
cd ..

git clone https://github.com/laytan/odin-http.git
mv ./odin-http ./http
rm -rf odin-http
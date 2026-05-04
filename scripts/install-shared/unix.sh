#!/usr/bin/env bash

ODIN_ROOT=$(odin root)
ODIN_SHARED="$ODIN_ROOT/shared"

cd $ODIN_SHARED

rm -rf sokol
rm -rf http

git clone https://github.com/floooh/sokol-odin.git
mv ./sokol-odin/sokol .
rm -rf sokol-odin

git clone https://github.com/laytan/odin-http.git
mv ./odin-http ./http
rm -rf odin-http
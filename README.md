# Sucata Player

The runtime/engine core of [Sucata](https://sucata.dev), a 2D game engine written in [Odin](https://odin-lang.org/) with [Lua](https://www.lua.org/) as the scripting language. This is the executable that actually loads and plays a Sucata game — driven by the sibling [sucata-cli](https://github.com/sucata-engine/sucata-cli) tool during development, and cloned + bundled with a game's assets to produce standalone distributables via `sucata build`.

Key dependencies: [sokol](https://github.com/floooh/sokol-odin) (graphics/app), [miniaudio](https://miniaud.io) (`vendor:miniaudio`, audio playback, decoding and mixing), [odin-http](https://github.com/laytan/odin-http), lz4 (asset compression), SDL3 (gamepad), and Lua 5.4. Supported audio formats: **WAV, MP3, OGG Vorbis and FLAC**.

On macOS and Linux the miniaudio static library is not shipped with Odin; `scripts/install-shared/unix.sh` builds it (it runs `$(odin root)/vendor/miniaudio/src/build_miniaudio.sh`). On Windows it comes prebuilt with the compiler.

## Shared Folder

- sokol -> https://github.com/floooh/sokol-odin (pinned to commit `49d76fd` by `scripts/install-shared`; update the commit there when moving to a newer sokol)
- http -> https://github.com/laytan/odin-http

## Setup project

1. Install [odin](https://odin-lang.org/) version: dev-2026-04-nightly:a896fb2
2. Install the shared libs, you can use `./scripts/install-shared/unix.sh` or `./scripts/install-shared/win.ps1`
3. Now you can edit!

## Build project

Just use the script for build a debug version: 
`./scripts/build-debug/unix.sh` or `./scripts/build-debug/win.ps1`

or release version:
`./scripts/build-release/unix.sh` or `./scripts/build-release/win.ps1`
#!/usr/bin/env bash

set -e

echo "Building Sucata for Unix..."

echo "Building sucata-player..."
odin build src/ -extra-linker-flags:"-L/opt/homebrew/lib"

echo "Done!"

#!/usr/bin/env bash

set -e

echo "Building Sucata for Unix..."

echo "Building sucata-player..."
odin build src/ -out:sucata-player -extra-linker-flags:"-rdynamic"

echo "Done!"

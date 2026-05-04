#!/usr/bin/env bash

set -e

echo "Building debug Sucata CLI for Unix..."

echo "Building debug sucata CLI..."
odin build src/ -out:sucata-player -debug -sanitize:address -extra-linker-flags:"-llua5.4"

echo "Done!"

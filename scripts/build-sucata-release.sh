#!/usr/bin/env bash

set -e

echo "Building Sucata for Unix..."

echo "Building sucata..."
odin build .

echo "Building sucata-player..."
odin build ./src/player.odin -file -out:sucata-player

mkdir -p release/unix

echo "Copying files..."
cp sucata release/unix/
cp sucata-player release/unix/

echo "Done!"

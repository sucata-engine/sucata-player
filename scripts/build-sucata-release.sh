#!/usr/bin/env bash

set -e

echo "Building Sucata for Unix..."

echo "Building sucata.exe..."
odin build .

echo "Building sucata-player.exe..."
odin build ./src/player.odin -file -out:sucata-player.exe

mkdir -p release/unix

echo "Copying files..."
cp sucata.exe release/unix/
cp sucata-player.exe release/unix/

echo "Done!"

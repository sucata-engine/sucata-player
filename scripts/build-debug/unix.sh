#!/usr/bin/env bash

set -e

echo "Building debug Sucata Player for Unix..."

echo "Building debug sucata Player..."
odin build src/ -out:sucata-player -debug -sanitize:address

echo "Done!"

#! /bin/bash

cd "$(dirname "$(which "$0")")/.." || exit 1

# Generate configure script
./build/autogen.sh

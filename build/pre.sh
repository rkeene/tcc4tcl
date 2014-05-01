#! /bin/bash

cd "$(dirname "$(which "$0")")/.." || exit 1

# Download latest copy of autoconf macros
(
	cd aclocal || exit 1

	for file in shobj.m4 tcl.m4 versionscript.m4; do
		rm -f "${file}"

		wget -O "${file}.new" "http://rkeene.org/devel/autoconf/${file}.m4" || continue

		mv "${file}.new" "${file}"
	done
)

# Generate configure script
./build/autogen.sh

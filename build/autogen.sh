#! /bin/bash

# Download latest copy of autoconf macros
(
	mkdir aclocal >/dev/null 2>/dev/null
	cd aclocal || exit 1

	for file in shobj.m4 tcl.m4 versionscript.m4; do
		rm -f "${file}"

		wget -O "${file}.new" "http://rkeene.org/devel/autoconf/${file}" || continue

		mv "${file}.new" "${file}"
	done
)

for file in config.guess config.sub install-sh; do
	rm -f "${file}"
done

aclocal -I aclocal
autoconf
automake -fca

rm -rf autom4te.cache

#! /usr/bin/env bash

cd "$(dirname "$(which "$0")")/.." || exit 1

# Generate configure script
./build/autogen.sh

# Download TCC
tcc_version='0.9.26'
tcc_url="http://download.savannah.gnu.org/releases/tinycc/tcc-${tcc_version}.tar.bz2"
tcc_sha256='521e701ae436c302545c3f973a9c9b7e2694769c71d9be10f70a2460705b6d71'
tcc_sha1='7110354d3637d0e05f43a006364c897248aed5d0'
(
	rm -rf __TMP__
	mkdir __TMP__ || exit 1
	cd __TMP__ || exit 1

	wget -O 'new' "${tcc_url}" || rm -f new
	new_hash="$(openssl sha256 new 2>/dev/null | sed 's@.*= *@@')"

	if [ -z "${new_hash}" ]; then
		new_hash="$(openssl sha1 new 2>/dev/null | sed 's@.*= *@@')"
		check_hash="${tcc_sha1}"
	else
		check_hash="${tcc_sha256}"
	fi

	if [ "${new_hash}" != "${check_hash}" ]; then
		echo "Checksum Mismatch: Downloaded: ${new_hash}; Expected: ${check_hash}" >&2

		rm -f new

		exit 1
	fi

	mv new "tcc-${tcc_version}.tar.bz2"

	bzip2 -dc "tcc-${tcc_version}.tar.bz2" | tar -xf -

	rm -f "tcc-${tcc_version}.tar.bz2"

	## Apply patches
	for patchfile in ../build/tcc-patches/${tcc_version}/*.diff; do
		( cd * && patch --no-backup-if-mismatch -p1 ) < "${patchfile}"
	done

	## Rename "Makefile" to "Makefile.in" so configure processes it
	( cd * && mv Makefile Makefile.in ) || exit 1

	rm -rf ../tcc
	mkdir ../tcc || exit 1
	mv */* ../tcc/
) || exit 1
rm -rf __TMP__

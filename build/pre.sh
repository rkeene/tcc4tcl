#! /bin/bash

cd "$(dirname "$(which "$0")")/.." || exit 1

# Generate configure script
./build/autogen.sh

# Download TCC
tcc_version='0.9.26'
tcc_url="http://download.savannah.gnu.org/releases/tinycc/tcc-${tcc_version}.tar.bz2"
tcc_sha256='521e701ae436c302545c3f973a9c9b7e2694769c71d9be10f70a2460705b6d71'
(
	rm -rf __TMP__
	mkdir __TMP__ || exit 1
	cd __TMP__ || exit 1

	wget -O 'new' "${tcc_url}" || rm -f new
	new_sha256="$(openssl sha256 new | sed 's@.*= *@@')"

	if [ "${new_sha256}" != "${tcc_sha256}" ]; then
		echo "Checksum Mismatch: Downloaded: ${new_sha256}; Expected: ${tcc_sha256}" >&2

		rm -f new

		exit 1
	fi

	mv new "tcc-${tcc_version}.tar.bz2"

	bzip2 -dc "tcc-${tcc_version}.tar.bz2" | tar -xf -

	rm -f "tcc-${tcc_version}.tar.bz2"

	## Apply patches
	for patchfile in ../build/tcc-patches/${tcc_version}/*.diff; do
		( cd * && patch -p1 ) < "${patchfile}"
	done

	rm -rf ../tcc
	mkdir ../tcc || exit 1
	mv */* ../tcc/
)
rm -rf __TMP__

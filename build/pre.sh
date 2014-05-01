#! /bin/bash

cd "$(dirname "$(which "$0")")/.." || exit 1

# Generate configure script
./build/autogen.sh

# Download TCC
(
	TCC_VERSION="0.9.26"
	TCC_URL="http://download.savannah.gnu.org/releases/tinycc/tcc-${TCC_VERSION}.tar.bz2"
	TCC_SHA256='521e701ae436c302545c3f973a9c9b7e2694769c71d9be10f70a2460705b6d71'

	rm -rf __TMP__
	mkdir __TMP__ || exit 1
	cd __TMP__ || exit 1
	wget -O tcc.tar.bz2.new "${TCC_URL}" || rm -f tcc.tar.bz2.new
	TCC_NEW_SHA256="$(openssl sha256 < tcc.tar.bz2.new | sed 's@.*= *@@')"

	if [ "${TCC_NEW_SHA256}" = "${TCC_SHA256}" ]; then
		mv tcc.tar.bz2.new tcc.tar.bz2
	fi

	tar -xf tcc.tar.bz2
	rm -f tcc.tar.bz2

	rm -rf ../tcc
	mkdir ../tcc || exit 1
	mv */* ../tcc/
)
rm -rf __TMP__

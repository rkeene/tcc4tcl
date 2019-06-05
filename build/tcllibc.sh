#! /usr/bin/env bash

cflags=(-DUSE_TCL_STUBS=1 -fPIC)
ldflags=()
libs=(-ltclstub8.6)

inFiles=(
	../../tcllib-fossil/modules/tcllibc.tcl
	../../tcllib-fossil/modules/md4/md4c.tcl
	../../tcllib-fossil/modules/struct/graph_c.tcl
	../../tcllib-fossil/modules/base32/base32_c.tcl
	../../tcllib-fossil/modules/struct/sets_c.tcl
	../../tcllib-fossil/modules/json/jsonc.tcl
	../../tcllib-fossil/modules/pt/pt_rdengine_c.tcl
	../../tcllib-fossil/modules/pt/pt_parse_peg_c.tcl
	../../tcllib-fossil/modules/uuid/uuid.tcl
	../../tcllib-fossil/modules/struct/tree_c.tcl
	../../tcllib-fossil/modules/base32/base32hex_c.tcl
	../../tcllib-fossil/modules/base64/base64c.tcl
	../../tcllib-fossil/modules/base64/uuencode.tcl
	../../tcllib-fossil/modules/base64/yencode.tcl
	../../tcllib-fossil/modules/sha1/sha1c.tcl
	../../tcllib-fossil/modules/md5/md5c.tcl
	../../tcllib-fossil/modules/crc/crcc.tcl
	../../tcllib-fossil/modules/crc/sum.tcl
	../../tcllib-fossil/modules/crc/crc32.tcl
	../../tcllib-fossil/modules/md5crypt/md5cryptc.tcl
	../../tcllib-fossil/modules/struct/queue_c.tcl
	../../tcllib-fossil/modules/rc4/rc4c.tcl
	../../tcllib-fossil/modules/sha1/sha256c.tcl
	../../tcllib-fossil/modules/struct/stack_c.tcl
	../../tcllib-fossil/modules/dns/ipMoreC.tcl
)

set -e

outDir=''
function cleanup() {
	local localOutDir

	localOutDir="${outDir}"
	outDir=''

	if [ -n "${localOutDir}" ]; then
		rm -rf "${localOutDir}"
	fi
}
trap cleanup EXIT

outDir="tmp-$(openssl rand 20 -hex)"
rm -rf "${outDir}"
mkdir "${outDir}"

for input in "${inFiles[@]}"; do
	out="${outDir}/$(basename "${input}" .tcl)"

	./tcc-critcl-to-c.tcl --mode direct "${input}" > "${out}.c"
	input_cflags=($(awk '/^CLI:/{ gsub(/^CLI:/, ""); print; }' < "${out}.c"))

	"${CC:-cc}" "${cflags[@]}" -Dinline= -o "${out}.o" "${input_cflags[@]}" -c "${out}.c" || continue
done

(
	cd "${outDir}" || exit 1

	cat << \_EOF_ > base.c
#include <tcl.h>
_EOF_

	for input in *.c; do
		object="$(basename "${input}" .c).o"
		if [ ! -f "${object}" ]; then
			continue
		fi

		grep '^/\* Immediate: ' "${input}"  | sed 's@^/\* Immediate: *@'$'\t''@;s@ *\*/$@@' | grep 'Tcl_CreateObjCommand' | cut -f 3 -d , | while IFS='' read -r symbol; do
			grep "${symbol}" "${input}" | grep -v '^/\* Immediate:' | sed 's@) {$@);@'
		done
	done >> base.c


	cat << \_EOF_ >> base.c
int Tcllibc_Init(Tcl_Interp *interp) {
#ifdef USE_TCL_STUBS
	if (Tcl_InitStubs(interp, TCL_PATCH_LEVEL, 0) == 0L) {
		return TCL_ERROR;
	}
#endif
_EOF_

	for input in *.c; do
		object="$(basename "${input}" .c).o"
		if [ ! -f "${object}" ]; then
			continue
		fi

		grep '^/\* Immediate: ' "${input}"  | sed 's@^/\* Immediate: *@'$'\t''@;s@ *\*/$@@' | sed 's@Tcc4tclDeleteClientData@NULL@g'
	done >> base.c

	cat << \_EOF_ >> base.c

	Tcl_PkgProvide(interp, "tcllibc", "0");

	return(TCL_OK);
}
_EOF_

	"${CC:-cc}" "${cflags[@]}" -o base.o -c base.c
)

cat << \_EOF_ > "${outDir}/version-script"
{
	global:
		Tcllibc_Init;
	local:
		*;
};
_EOF_

"${CC:-cc}" "${cflags[@]}" "${ldflags[@]}" -Wl,--version-script,"${outDir}/version-script" -shared -o tcllibc.so "${outDir}"/*.o "${libs[@]}"
"${OBJCOPY:-objcopy}" --keep-global-symbol Tcllibc_Init tcllibc.so
"${OBJCOPY:-objcopy}" --discard-all tcllibc.so

exit 0

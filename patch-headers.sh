#! /bin/bash

headers_dir="$1"

cd "${headers_dir}" || exit 1

# Android header fix-ups
## Do not abort compilation at header include time
if grep '^#error "No function renaming possible"' sys/cdefs.h >/dev/null 2>/dev/null; then
	awk '
/#error "No function renaming possible"/{
	print "#define __RENAME(x) no renaming on this platform"
	next
}
{print}
	' sys/cdefs.h > sys/cdefs.h.new
	cat sys/cdefs.h.new > sys/cdefs.h
	rm -f sys/cdefs.h.new
fi

## loff_t depends on __GNUC__ for some reason
if awk -v retval=1 '/__GNUC__/{ getline; if ($0 ~ /__kernel_loff_t/) {retval=0} } END{exit retval}' asm/posix_types.h >/dev/null 2>/dev/null; then
	awk '/__GNUC__/{ getline; if ($0 ~ /__kernel_loff_t/) { print "#if 1"; print; next } } { print }' asm/posix_types.h > asm/posix_types.h.new
	cat asm/posix_types.h.new > asm/posix_types.h
	rm -f asm/posix_types.h.new
fi

# Busted wrapper fix-up
if grep '__STDC_HOSTED__' stdint.h >/dev/null 2>/dev/null && grep '_GCC_WRAP_STDINT_H' stdint.h >/dev/null 2>/dev/null; then
	echo '#include_next <stdint.h>' > stdint.h
fi

# MUSL libc expects GCC
if grep ' __builtin_va_list ' bits/alltypes.h >/dev/null 2>/dev/null; then
	sed 's@ __builtin_va_list @ char * @' bits/alltypes.h > bits/alltypes.h.new
	cat bits/alltypes.h.new > bits/alltypes.h
	rm -f bits/alltypes.h.new
fi

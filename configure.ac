dnl Define ourselves
AC_INIT(tcc4tcl, @@VERS@@)

dnl Checks for programs.
AC_PROG_CC
AC_PROG_MAKE_SET
AC_PROG_INSTALL
AC_GNU_SOURCE
AC_LANG(C)

dnl Determine system information
DC_CHK_OS_INFO

dnl Determine if a shared or static build is requested
AC_ARG_ENABLE([shared], AS_HELP_STRING([--disable-shared], [build static library instead of shared library]), [
	if test "$enableval" = "no"; then
		TCC4TCL_TARGET=static
	else
		TCC4TCL_TARGET=shared
	fi
], [
	TCC4TCL_TARGET=shared
])

dnl Configure TCC build options
AC_SUBST(TCC_CONFIGURE_OPTS)
TCC_CONFIGURE_OPTS=""

dnl -- If cross-compiling, specify a "--cross-prefix" and define the CPU
if test "${host}" != "${build}"; then
	TCC_CONFIGURE_OPTS="${TCC_CONFIGURE_OPTS} --cross-prefix=${host_alias}- --cpu=${host_cpu} --os=${host_os}"
fi

if test "${TCC4TCL_TARGET}" = "shared"; then
	dnl Determine how to make shared objects
	DC_GET_SHOBJFLAGS

	dnl Only export symbols we wish to expose
	TARGET="tcc4tcl.${SHOBJEXT}"
else
	TCC_EXTRA_CFLAGS="${TCC_EXTRA_CFLAGS} -DCONFIG_TCC_STATIC=1"

	AC_CHECK_TOOL([RANLIB], [ranlib])
	AC_CHECK_TOOL([AR], [ar])

	TARGET="tcc4tcl-static.a"
fi
AC_SUBST(TARGET)
AC_SUBST(TCC4TCL_TARGET)
AC_SUBST(TCC_EXTRA_CFLAGS)

no_dlopen='0'
AC_ARG_WITH([dlopen], AS_HELP_STRING([--without-dlopen], [do not define dlopen/dlclose/dlerror]), [
	if test "$withval" = "no"; then
		no_dlopen='1'
	else
		no_dlopen='0'
	fi
])

if test "$no_dlopen" = '1'; then
	CPPFLAGS="${CPPFLAGS} -DCONFIG_TCC_STATIC_NODLOPEN=1"
fi

dnl Determine HOST_PATH_SEPERATOR
case $host_os in
	*mingw*)
		HOST_PATH_SEPARATOR=';'
		;;
	*)
		HOST_PATH_SEPARATOR=':'
		;;
esac
AC_SUBST(HOST_PATH_SEPARATOR)

dnl Perform Tcl Extension required stuff
TCLEXT_INIT

dnl This must be done last since it breaks the compilation
if test "${TCC4TCL_TARGET}" = "shared"; then
	DC_SETVERSIONSCRIPT([${srcdir}/tcc4tcl.vers], [tcc4tcl.syms])
	DC_FIND_STRIP_AND_REMOVESYMS([tcc4tcl.syms])
fi

dnl Produce output
AC_OUTPUT(Makefile pkgIndex.tcl tcc4tcl.syms)

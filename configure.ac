dnl Define ourselves
AC_INIT(tcc4tcl, @@VERS@@)

dnl Checks for programs.
AC_PROG_CC
AC_PROG_MAKE_SET
AC_PROG_INSTALL
AC_GNU_SOURCE

dnl Determine system information
DC_CHK_OS_INFO

dnl Determine if a shared or static build is requested
AC_ARG_ENABLE([static], AS_HELP_STRING([--enable-static], [build static library instead of shared library]), [
	if test "$enableval" = "no"; then
		TCC4TCL_TARGET=static
	else
		TCC4TCL_TARGET=shared
	fi
], [
	TCC4TCL_TARGET=shared
])

TCC_CONFIGURE_OPTS=""
if test "${TCC4TCL_TARGET}" = "shared"; then
	dnl Determine how to make shared objects
	DC_GET_SHOBJFLAGS

	dnl Only export symbols we wish to expose
	DC_SETVERSIONSCRIPT([tcltcc.syms], [tcltcc.vers])
	DC_FIND_STRIP_AND_REMOVESYMS([tcltcc.syms])

	TARGET="tcltcc.${SHOBJEXT}"
else
	TARGET="tcltcc-static.a"
fi
AC_SUBST(TARGET)
AC_SUBST(TCC4TCL_TARGET)
AC_SUBST(TCC_CONFIGURE_OPTS)

dnl Find out if we have the functions needed to open shared objects
AC_SEARCH_LIBS(dlopen, dl,, [
        AC_SEARCH_LIBS(shl_load, dld dl)
])
AC_CHECK_FUNCS(dlopen shl_load)

dnl Look for appropriate headers
AC_CHECK_HEADERS(unistd.h stdlib.h string.h strings.h dlfcn.h dl.h)

dnl Perform Tcl Extension required stuff
TCLEXT_INIT

dnl Produce output
AC_OUTPUT(Makefile pkgIndex.tcl tcltcc.syms)

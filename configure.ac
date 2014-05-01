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
target=shared
AC_ARG_ENABLE([static], AS_HELP_STRING([--enable-static], [build static library instead of shared library]), [
	target=static
], [
	target=shared
])

if test "${target}" = "shared"; then
	dnl Determine how to make shared objects
	DC_GET_SHOBJFLAGS

	TARGETS="tcltcc-shared.${SHOBJEXT}"
else
	TARGETS="tcltcc-static.a"
fi
AC_SUBST(TARGETS)

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
AC_OUTPUT(Makefile pkgIndex.tcl)

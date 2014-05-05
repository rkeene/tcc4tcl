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
AC_ARG_ENABLE([static], AS_HELP_STRING([--enable-static], [build static library instead of shared library]), [
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

	AC_CHECK_HEADERS(windows.h)
	AC_CHECK_HEADERS(psapi.h,,, [
#ifdef HAVE_WINDOWS_H
#  include <windows.h>
#endif
])

	AC_MSG_CHECKING([for EnumProcessModules in -lpsapi])
	SAVE_LIBS="$LIBS"
	LIBS="-lpsapi $LIBS"
	AC_LINK_IFELSE([AC_LANG_PROGRAM([
#ifdef HAVE_WINDOWS_H
#  include <windows.h>
#endif
#ifdef HAVE_PSAPI_H
#  include <psapi.h>
#endif
], [
	EnumProcessModules(NULL, NULL, 0, NULL);
])], [
	AC_MSG_RESULT([found])
], [
	AC_MSG_RESULT([not found])
	LIBS="$SAVE_LIBS"
])
else
	TARGET="tcc4tcl-static.a"
fi
AC_SUBST(TARGET)
AC_SUBST(TCC4TCL_TARGET)

dnl Find out if we have the functions needed to open shared objects
AC_SEARCH_LIBS(dlopen, dl,, [
        AC_SEARCH_LIBS(shl_load, dld dl)
])
AC_CHECK_FUNCS(dlopen shl_load)

dnl Look for appropriate headers
AC_CHECK_HEADERS(unistd.h stdlib.h string.h strings.h dlfcn.h dl.h)

dnl Perform Tcl Extension required stuff
TCLEXT_INIT

dnl This must be done last since it breaks the compilation
if test "${TCC4TCL_TARGET}" = "shared"; then
	DC_SETVERSIONSCRIPT([tcc4tcl.syms], [tcc4tcl.vers])
	DC_FIND_STRIP_AND_REMOVESYMS([tcc4tcl.syms])
fi

dnl Produce output
AC_OUTPUT(Makefile pkgIndex.tcl tcc4tcl.syms)

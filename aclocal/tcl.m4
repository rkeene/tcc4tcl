dnl Tcl M4 Routines

dnl Must call AC_CANONICAL_HOST  before calling us
AC_DEFUN([TCLEXT_FIND_TCLCONFIG], [
	AC_MSG_CHECKING([for path to tclConfig.sh])

	TCLCONFIGPATH=""
	AC_ARG_WITH([tcl], AS_HELP_STRING([--with-tcl], [directory containing tcl configuration (tclConfig.sh)]), [
		if test "x$withval" = "xno"; then
			AC_MSG_ERROR([cant build without tcl])
		fi

		TCLCONFIGPATH="$withval"
	], [
		for dir in "/usr/$host_alias/lib" /usr/lib /usr/lib64 /usr/local/lib /usr/local/lib64; do
			if test -f "$dir/tclConfig.sh"; then
				TCLCONFIGPATH="$dir"

				break
			fi
		done
	])

	if test -z "$TCLCONFIGPATH"; then
		AC_MSG_ERROR([unable to locate tclConfig.sh.  Try --with-tcl.])
	fi

	for try_tclsh in "$TCLCONFIGPATH/../bin/tclsh" \
	                 "$TCLCONFIGPATH/../bin/tclsh8.6" \
	                 "$TCLCONFIGPATH/../bin/tclsh8.5" \
	                 "$TCLCONFIGPATH/../bin/tclsh8.4" \
	                 `which tclsh 2>/dev/null` \
	                 `which tclsh8.6 2>/dev/null` \
	                 `which tclsh8.5 2>/dev/null` \
	                 `which tclsh8.4 2>/dev/null` \
	                 tclsh; do
		if test -x "$try_tclsh"; then
			break
		fi
	done
	TCLSH_PROG="${try_tclsh}"

	AC_SUBST(TCLCONFIGPATH)
	AC_SUBST(TCLSH_PROG)

	AC_MSG_RESULT([$TCLCONFIGPATH])
])

dnl Must define TCLCONFIGPATH before calling us (i.e., by TCLEXT_FIND_TCLCONFIG)
AC_DEFUN([TCLEXT_LOAD_TCLCONFIG], [
	AC_MSG_CHECKING([for working tclConfig.sh])

	if test -f "$TCLCONFIGPATH/tclConfig.sh"; then
		. "$TCLCONFIGPATH/tclConfig.sh"
	else
		AC_MSG_ERROR([unable to load tclConfig.sh])
	fi


	AC_MSG_RESULT([found])
])

AC_DEFUN([TCLEXT_INIT], [
	AC_CANONICAL_HOST

	TCLEXT_FIND_TCLCONFIG
	TCLEXT_LOAD_TCLCONFIG

	AC_DEFINE_UNQUOTED([MODULE_SCOPE], [static], [Define how to declare a function should only be visible to the current module])

	AC_ARG_ENABLE([stubs], AS_HELP_STRING([--disable-stubs], [disable use of Tcl stubs]), [
		if test "$enableval" = "no"; then
			TCL_SUPPORTS_STUBS=0
		else
			TCL_SUPPORTS_STUBS=1
		fi
	])

	if test "$TCL_SUPPORTS_STUBS" = "1"; then
		AC_DEFINE([USE_TCL_STUBS], [1], [Define if you are using the Tcl Stubs Mechanism])

		TCL_STUB_LIB_SPEC="`eval echo "${TCL_STUB_LIB_SPEC}"`"
		LIBS="${LIBS} ${TCL_STUB_LIB_SPEC}"
	else
		TCL_LIB_SPEC="`eval echo "${TCL_LIB_SPEC}"`"
		LIBS="${LIBS} ${TCL_LIB_SPEC}"
	fi

	TCL_INCLUDE_SPEC="`eval echo "${TCL_INCLUDE_SPEC}"`"

	CFLAGS="${CFLAGS} ${TCL_INCLUDE_SPEC}"
	CPPFLAGS="${CPPFLAGS} ${TCL_INCLUDE_SPEC}"
	DEFS="${DEFS} ${TCL_DEFS}"

	dnl Needed for package installation
	TCL_PACKAGE_PATH="`echo "${TCL_PACKAGE_PATH}" | sed 's@  *$''@@' | awk '{ print [$]1 }'`"
	AC_SUBST(TCL_PACKAGE_PATH)

	AC_SUBST(LIBS)
])

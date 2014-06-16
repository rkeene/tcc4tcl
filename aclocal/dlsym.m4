AC_DEFUN([TCC4TCL_FIND_DLOPEN], [
	AC_CHECK_HEADERS_ONCE([dlfcn.h])

	AC_SEARCH_LIBS([dlsym], [dl dld], [
		AC_DEFINE([HAVE_DLSYM], [1], [Have the dlsym function])
	], [
		AC_CHECK_HEADERS([windows.h])

		AC_MSG_CHECKING([for working EnumProcessModules])
		SAVE_LIBS="$LIBS"
		LIBS="$LIBS -lpsapi"
		AC_LINK_IFELSE([
			AC_LANG_PROGRAM([
#ifdef HAVE_WINDOWS_H
#  include <windows.h>
#endif
#include <psapi.h>
			], [
HANDLE cur_proc;
DWORD needed;

needed = 0;

cur_proc = GetCurrentProcess();
EnumProcessModules(cur_proc, NULL, 0, &needed);
			]
		)], [
			AC_DEFINE([HAVE_ENUMPROCESSMODULES], [1], [Have the EnumProcessModules function])
			AC_DEFINE([HAVE_PSAPI_H], [1], [Have the psapi.h header file])
			AC_MSG_RESULT([found])
		], [
			LIBS="$SAVE_LIBS"
			AC_MSG_RESULT([not found])
		])
	])
])

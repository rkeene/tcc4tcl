# tcc.tcl - library routines for the tcc wrapper (Mark Janssen)

namespace eval tcc4tcl {
	variable dir 
	variable count

	set dir [file dirname [info script]]

	if {[info command ::tcc4tcl] == ""} {
		catch { load {} tcc4tcl }
	}
	if {[info command ::tcc4tcl] == ""} {
		load [file join $dir tcc4tcl[info sharedlibextension]] tcc4tcl
	}

	set count 0

	proc new {{output ""} {pkgName ""}} {
		variable dir
		variable count

		set handle ::tcc4tcl::tcc_[incr count]

		if {$output == ""} {
			set type "memory"
		} else {
			if {$pkgName == ""} {
				set type "exe"
			} else {
				set type "package"
			}
		}

		array set $handle [list code "" type $type filename $output package $pkgName add_inc_path "" add_lib_path "" add_lib ""]

		proc $handle {cmd args} [string map [list @@HANDLE@@ $handle] {
			set handle {@@HANDLE@@}

			if {$cmd == "go"} {
				set args [list 0 {*}$args]
			}

			if {$cmd == "code"} {
				set cmd "go"
				set args [list 1 {*}$args]
			}

			set callcmd ::tcc4tcl::_$cmd

			if {[info command $callcmd] == ""} {
				return -code error "unknown or ambiguous subcommand \"$cmd\": must be cproc, linktclcommand, code, tk, or go"
			}

			uplevel 1 [list $callcmd $handle {*}$args]
		}]

		return $handle
	}

	proc _linktclcommand {handle cSymbol tclCommand} {
		upvar #0 $handle state

		lappend state(procs) $cSymbol $tclCommand
	}

	proc _add_include_path {handle args} {
		upvar #0 $handle state

		lappend state(add_inc_path) {*}$args
	}

	proc _add_library_path {handle args} {
		upvar #0 $handle state

		lappend state(add_lib_path) {*}$args
	}

	proc _add_library {handle args} {
		upvar #0 $handle state

		lappend state(add_lib) {*}$args
	}

	proc _cwrap {handle name adefs rtype} {
		upvar #0 $handle state

		set wrap [uplevel 1 [list ::tcc4tcl::wrap $name $adefs $rtype "#" "" 1]]

		set wrapped [lindex $wrap 0]
		set wrapper [lindex $wrap 1]
		set tclname [lindex $wrap 2]

		append state(code) $wrapped "\n"
		append state(code) $wrapper "\n"

		lappend state(procs) $name $tclname
	}

	proc _cproc {handle name adefs rtype {body "#"}} {
		upvar #0 $handle state

		set wrap [uplevel 1 [list ::tcc4tcl::wrap $name $adefs $rtype $body]]

		set wrapped [lindex $wrap 0]
		set wrapper [lindex $wrap 1]
		set tclname [lindex $wrap 2]

		append state(code) $wrapped "\n"
		append state(code) $wrapper "\n"

		lappend state(procs) $name $tclname
	}

	proc _ccode {handle code} {
		upvar #0 $handle state

		append state(code) $code "\n"
	}

	proc _tk {handle} {
		upvar #0 $handle state

		set state(tk) 1
	}

	proc _delete {handle} {
		rename $handle ""
		unset $handle
	}

	proc _proc {handle cname adefs rtype body args} {
		# Convert body into a C-style string
		binary scan $body H* cbody
		set cbody [regsub -all {..} $cbody {\\x&}]

		# Parse optional arguments
		foreach {argname argval} $args {
			switch -- $argname {
				"-error" {
					set returnErrorValue $argval
				}
			}
		}

		# Argument definitions (in C style) initialization
		set adefs_c [list]

		# Names of all arguments initialization
		set args [list]

		# If we aren't creating a new interp, it must be the first argument
		# If the definition of this proc already includes the interp
		# argument, use it -- otherwise add one
		set newInterp 1
		foreach {type var} $adefs {
			if {$type == "Tcl_Interp*"} {
				set newInterp 0
				set interp_name $var

				break
			}
		}

		# Create the C-style argument definition
		foreach {type var} $adefs {
			lappend adefs_c [list $type $var]
			set types($var) $type

			if {$type == "Tcl_Interp*"} {
				continue
			}

			lappend args $var
		}

		if {[llength $adefs_c] == 0} {
			set adefs_c "void"
		} else {
			set adefs_c [join $adefs_c {, }]
		}

		# Determine how to return in failure
		if {$rtype != "void"} {
			if {[info exists returnErrorValue]} {
				set return_failure "return(${returnErrorValue})"
			} else {
				switch -- $rtype {
					int - long - Tcl_WideInt {
						set return_failure "return(-1)"
					}
					ok {
						set return_failure "return(TCL_ERROR)"
					}
					double - float {
						set return_failure "return(($rtype) ((($rtype) 1.0) / (($rtype) 0.0)))"
					}
					default {
						set return_failure "return(NULL)"
					}
				}
			}
		} else {
			set return_failure "return"
		}

		# Define the C function
		_ccode $handle "$rtype $cname\($adefs_c) \{"

		## Define the Tcl return value checking variable
		_ccode $handle "    int tclrv;"

		## If the interpreters return value is relevant, create a variable to store it
		if {$rtype != "ok" && $rtype != "void"} {
			_ccode $handle "    Tcl_Obj *rv_interp;"
		}

		## If we are returning a value, declare a variable for that
		if {$rtype != "void"} {
			_ccode $handle "    $rtype rv;"
		}

		## If we need to create a new interpreter, do so
		if {$newInterp} {
			set interp_name "ip"
			_ccode $handle "    Tcl_Interp *${interp_name};"
		}

		# Declare Tcl_Obj variables
		_ccode $handle "    Tcl_Obj *_[join $args {, *_}];"

		_ccode $handle ""

		if {$newInterp} {
			_ccode $handle "    ${interp_name}  = Tcl_CreateInterp();"
			_ccode $handle "    if (!${interp_name}) $return_failure;"
			_ccode $handle ""
		}

		# Process all arguments
		foreach arg $args {
			set type $types($arg)
			switch -- $type {
				int - long - Tcl_WideInt - float - double {
					switch -- $type {
						float {
							set convCmd Double
						}
						Tcl_WideInt {
							set convCmd WideInt
						}
						default {
							set convCmd [string totitle $type]
						}
					}

					_ccode $handle "    _$arg = Tcl_New${convCmd}Obj($arg);"
					_ccode $handle "    if (!_$arg) $return_failure;"
				}
				char* {
					_ccode $handle "    _$arg = Tcl_NewStringObj($arg, -1);"
				}
				Tcl_Obj* {
					_ccode $handle "    _$arg = $arg;"
				}
				default {
					return -code error "Unknown type: $type"
				}
			}
			_ccode $handle "    if (!Tcl_ObjSetVar2(${interp_name}, Tcl_NewStringObj(\"${arg}\", -1), NULL, _$arg, 0)) $return_failure;"
		}

		_ccode $handle ""
		_ccode $handle "    tclrv = Tcl_Eval($interp_name, \"$cbody\");"
		_ccode $handle "    if (tclrv != TCL_OK && tclrv != TCL_RETURN) $return_failure;"
		_ccode $handle ""

		if {$rtype != "ok" && $rtype != "void"} {
			_ccode $handle "    rv_interp = Tcl_GetObjResult(${interp_name});"
		}

		switch -- $rtype {
			void { }
			ok {
				_ccode $handle "    rv = 0;"
			}
			int {
				_ccode $handle "    if (Tcl_GetIntFromObj(ip, rv_interp, &rv) != TCL_OK) $return_failure;"
			}
			long {
				_ccode $handle "    if (Tcl_GetLongFromObj(ip, rv_interp, &rv) != TCL_OK) $return_failure;"
			}
			Tcl_WideInt {
				_ccode $handle "    if (Tcl_GetWideIntFromObj(ip, rv_interp, &rv) != TCL_OK) $return_failure;"
			}
			float {
				_ccode $handle "    {"
				_ccode $handle "        double t;"
				_ccode $handle "        if (Tcl_GetDoubleFromObj(ip, rv_interp, &t) != TCL_OK) $return_failure;"
				_ccode $handle "        rv = (float) t;"
				_ccode $handle "    }"
			}
			double {
				_ccode $handle "    if (Tcl_GetDoubleFromObj(ip, rv_interp, &rv) != TCL_OK) $return_failure;"
			}
			char* {
				_ccode $handle "    rv = Tcl_GetString(rv_interp);"
			}
			Tcl_Obj* {
				_ccode $handle "    rv = rv_interp;"
			}
		}

		_ccode $handle ""
		if {$rtype != "void"} {
			_ccode $handle "    return(rv);"
		} else {
			_ccode $handle "    return;"
		}
		_ccode $handle "\}"
	}

	proc _go {handle {outputOnly 0}} {
		variable dir

		upvar #0 $handle state

		set code $state(code)

		if {$state(type) == "exe" || $state(type) == "dll"} {
			if {[info exists state(procs)] && [llength $state(procs)] > 0} {
				set code "int _initProcs(Tcl_Interp *interp);\n\n$code"
			}
		}

		if {[info exists state(tk)]} {
			set code "#include <tk.h>\n$code"
		}
		set code "#include <tcl.h>\n\n$code"

		# Append additional generated code to support the output type
		switch -- $state(type) {
			"memory" {
				# No additional code needed
				if {$outputOnly} {
					if {[info exists state(procs)] && [llength $state(procs)] > 0} {
						foreach {procname cname} $state(procs) {
							append code "/* Immediate: Tcl_CreateObjCommand(interp, \"$procname\", $cname, NULL, NULL); */\n"
						}
					}
				}
			}
			"exe" - "dll" {
				if {[info exists state(procs)] && [llength $state(procs)] > 0} {
					append code "int _initProcs(Tcl_Interp *interp) \{\n"
					
					foreach {procname cname} $state(procs) {
						append code "  Tcl_CreateObjCommand(interp, \"$procname\", $cname, NULL, NULL);\n"
					}

					append code "\}"
				}
			}
			"package" {
				set packageName [lindex $state(package) 0]
				set packageVersion [lindex $state(package) 1]
				if {$packageVersion == ""} {
					set packageVersion "0"
				}

				append code "int [string totitle $packageName]_Init(Tcl_Interp *interp) \{\n"
				append code "#ifdef USE_TCL_STUBS\n"
				append code "  if (Tcl_InitStubs(interp, TCL_VERSION, 0) == 0L) \{\n"
				append code "    return TCL_ERROR;\n"
				append code "  \}\n"
				append code "#endif\n"

				if {[info exists state(procs)] && [llength $state(procs)] > 0} {
					foreach {procname cname} $state(procs) {
						append code "  Tcl_CreateObjCommand(interp, \"$procname\", $cname, NULL, NULL);\n"
					}
				}

				append code "  Tcl_PkgProvide(interp, \"$packageName\", \"$packageVersion\");\n"
				append code "  return(TCL_OK);\n"
				append code "\}"
			}
		}

		if {$outputOnly} {
			return $code
		}

		# Generate output code
		switch -- $state(type) {
			"package" {
				set tcc_type "dll"
			}
			default {
				set tcc_type $state(type)
			}
		}

		if {[info command ::tcc4tcl] == ""} {
			return -code error "Unable to load tcc4tcl library"
		}

		::tcc4tcl $dir $tcc_type tcc

		foreach path $state(add_inc_path) {
			tcc add_include_path $path
		}

		foreach path $state(add_lib_path) {
			tcc add_library_path $path
		}

		foreach lib $state(add_lib) {
			tcc add_library $lib
		}

		switch -- $state(type) {
			"memory" {
				tcc compile $code

				if {[info exists state(procs)] && [llength $state(procs)] > 0} {
					foreach {procname cname} $state(procs) {
						tcc command $procname $cname
					}
				}
			}

			"package" - "dll" - "exe" {
				switch -glob -- $::tcl_platform(os)-$::tcl_platform(pointerSize) {
					"Linux-8" {
						tcc add_library_path "/lib64"
						tcc add_library_path "/usr/lib64"
						tcc add_library_path "/lib"
						tcc add_library_path "/usr/lib"
					}
					"SunOS-8" {
						tcc add_library_path "/lib/64"
						tcc add_library_path "/usr/lib/64"
						tcc add_library_path "/lib"
						tcc add_library_path "/usr/lib"
					}
					"Linux-*" {
						tcc add_library_path "/lib32"
						tcc add_library_path "/usr/lib32"
						tcc add_library_path "/lib"
						tcc add_library_path "/usr/lib"
					}
					default {
						if {$::tcl_platform(platform) == "unix"} {
							tcc add_library_path "/lib"
							tcc add_library_path "/usr/lib"
						}
					}
				}

				tcc compile $code

				tcc output_file $state(filename)
			}
		}

		# Cleanup
		rename $handle ""
		unset $handle
	}
}

proc ::tcc4tcl::checkname {n} {expr {[regexp {^[a-zA-Z0-9_]+$} $n] > 0}}
proc ::tcc4tcl::cleanname {n} {regsub -all {[^a-zA-Z0-9_]+} $n _}

proc ::tcc4tcl::cproc {name adefs rtype {body "#"}} {
	set handle [::tcc4tcl::new]
	$handle cproc $name $adefs $rtype $body
	return [$handle go]
}

proc ::tcc4tcl::wrap {name adefs rtype {body "#"} {cname ""} {includePrototype 0}} {
	if {$cname == ""} {
		set cname c_[tcc4tcl::cleanname $name]
	}

	set wname tcl_[tcc4tcl::cleanname $name]

	# Fully qualified proc name
	if {![string match "::*" $name]} {
		set nsfrom [uplevel 1 {namespace current}]    
		if {$nsfrom eq "::"} {
			set nsfrom ""
		}

		set name "${nsfrom}::${name}"
	}

	array set types {}
	set varnames {}
	set cargs {}
	set cnames {}  
	set cbody {}
	set code {}

	# Write wrapper
	append cbody "int $wname\(ClientData dummy, Tcl_Interp *ip, int objc, Tcl_Obj *CONST objv\[\]) {" "\n"

	# if first arg is "Tcl_Interp*", pass it without counting it as a cmd arg
	if {[lindex $adefs 0] eq "Tcl_Interp*"} {
		lappend cnames ip
		lappend cargs [lrange $adefs 0 1]
		set adefs [lrange $adefs 2 end]
	}

	foreach {t n} $adefs {
		set types($n) $t
		lappend varnames $n
		lappend cnames _$n
		lappend cargs "$t $n"
	}

	# Handle return type
	switch -- $rtype {
		ok      {
			set rtype2 "int"
		}
		string - dstring - vstring {
			set rtype2 "char*"
		}
		default {
			set rtype2 $rtype
		}
	}

	# Create wrapped function
	if {[llength $cargs] != 0} {
		set cargs_str [join $cargs {, }]
	} else {
		set cargs_str "void"
	}

	if {$body ne "#"} {
		append code "static $rtype2 ${cname}($cargs_str) \{\n"
		append code $body
		append code "\}\n"
	} else {
		set cname [namespace tail $name]

		if {$includePrototype} {
			append code "$rtype2 ${cname}($cargs_str);\n"
		}
	}

	# Create wrapper function
	## Supported input types
	##   Tcl_Interp*
	##   int
	##   long
	##   float
	##   double
	##   char*
	##   Tcl_Obj*
	##   void*
	##   Tcl_WideInt
	foreach x $varnames {
		set t $types($x)

		switch -- $t {
			int - long - float - double - char* - Tcl_WideInt - Tcl_Obj* {
				append cbody "  $types($x) _$x;" "\n"
			}
			default {
				append cbody "  void *_$x;" "\n"
			}
		}
	}

	if {$rtype ne "void"} {
		append cbody  "  $rtype2 rv;" "\n"
	}  

	append cbody "  if (objc != [expr {[llength $varnames] + 1}]) {" "\n"
	append cbody "    Tcl_WrongNumArgs(ip, 1, objv, \"[join $varnames { }]\");\n"
	append cbody "    return TCL_ERROR;" "\n"
	append cbody "  }" "\n"

	set n 0
	foreach x $varnames {
		incr n
		switch -- $types($x) {
			int {
				append cbody "  if (Tcl_GetIntFromObj(ip, objv\[$n], &_$x) != TCL_OK)"
				append cbody "    return TCL_ERROR;" "\n"
			}
			long {
				append cbody "  if (Tcl_GetLongFromObj(ip, objv\[$n], &_$x) != TCL_OK)"
				append cbody "    return TCL_ERROR;" "\n"
			}
			Tcl_WideInt {
				append cbody "  if (Tcl_GetWideIntFromObj(ip, objv\[$n], &_$x) != TCL_OK)"
				append cbody "    return TCL_ERROR;" "\n"
			}
			float {
				append cbody "  {" "\n"
				append cbody "    double t;" "\n"
				append cbody "    if (Tcl_GetDoubleFromObj(ip, objv\[$n], &t) != TCL_OK)"
				append cbody "      return TCL_ERROR;" "\n"
				append cbody "    _$x = (float) t;" "\n"
				append cbody "  }" "\n"
			}
			double {
				append cbody "  if (Tcl_GetDoubleFromObj(ip, objv\[$n], &_$x) != TCL_OK)"
				append cbody "    return TCL_ERROR;" "\n"
			}
			char* {
				append cbody "  _$x = Tcl_GetString(objv\[$n]);" "\n"
			}
			default {
				append cbody "  _$x = objv\[$n];" "\n"
			}
		}
	}
	append cbody "\n"

	# Call wrapped function
	if {$rtype != "void"} {
		append cbody "  rv = "
	}
	append cbody "${cname}([join $cnames {, }]);" "\n"

	# Return types supported by critcl
	#   void
	#   ok
	#   int
	#   long
	#   float
	#   double
	#   char*     (TCL_STATIC char*)
	#   string    (TCL_DYNAMIC char*)
	#   dstring   (TCL_DYNAMIC char*)
	#   vstring   (TCL_VOLATILE char*)
	#   default   (Tcl_Obj*)
	#   Tcl_WideInt
	switch -- $rtype {
		void - ok - int - long - float - double - Tcl_WideInt {}
		default {
			append cbody "  if (rv == NULL) {\n"
			append cbody "    return(TCL_ERROR);\n"
			append cbody "  }\n"
		}
	}

	switch -- $rtype {
		void           { }
		ok             { append cbody "  return rv;" "\n" }
		int            { append cbody "  Tcl_SetIntObj(Tcl_GetObjResult(ip), rv);" "\n" }
		long           { append cbody "  Tcl_SetLongObj(Tcl_GetObjResult(ip), rv);" "\n" }
		Tcl_WideInt    { append cbody "  Tcl_SetWideIntObj(Tcl_GetObjResult(ip), rv);" "\n" }
		float          -
		double         { append cbody "  Tcl_SetDoubleObj(Tcl_GetObjResult(ip), rv);" "\n" }
		char*          { append cbody "  Tcl_SetResult(ip, rv, TCL_STATIC);" "\n" }
		string         -
		dstring        { append cbody "  Tcl_SetResult(ip, rv, TCL_DYNAMIC);" "\n" }
		vstring        { append cbody "  Tcl_SetResult(ip, rv, TCL_VOLATILE);" "\n" }
		default        { append cbody "  Tcl_SetObjResult(ip, rv); Tcl_DecrRefCount(rv);" "\n" }
	}

	if {$rtype != "ok"} {
		append cbody "  return TCL_OK;\n"
	}

	append cbody "}" "\n"

	return [list $code $cbody $wname]
}

namespace eval tcc4tcl {namespace export cproc new}

package provide tcc4tcl "@@VERS@@"

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
		set tcc_handle ::tcc4tcl::tcc_[incr count]

		if {$output == ""} {
			set type "memory"
		} else {
			set type "dll"
		}

		array set $handle [list tcc $tcc_handle code "" type $type filename $output package $pkgName]

		proc $handle {cmd args} [string map [list @@HANDLE@@ $handle] {
			set handle {@@HANDLE@@}
			uplevel 1 [list ::tcc4tcl::_$cmd $handle {*}$args]
		}]

		return $handle
	}

	proc _cproc {handle name adefs rtype {body "#"}} {
		upvar #0 $handle state

		set wrap [::tcc4tcl::wrap $name $adefs $rtype $body]

		set wrapped [lindex $wrap 0]
		set wrapper [lindex $wrap 1]
		set tclname [lindex $wrap 2]

		append state(code) $wrapped "\n"
		append state(code) $wrapper "\n"

		lappend state(procs) $name $tclname
	}

	proc _ccode {handle code} {
		upvar #0 $handle state

		append state(code) $code
	}

	proc _tk {handle} {
		upvar #0 $handle state

		set state(tk) 1
	}

	proc _go {handle} {
		variable dir

		upvar #0 $handle state

		if {[info exists state(tk)]} {
			set state(code) "#include <tk.h>\n$state(code)"
		}
		set state(code) "#include <tcl.h>\n\n$state(code)"

		tcc4tcl $dir $state(type) tcc

		switch -- $state(type) {
			"memory" {
				tcc compile $state(code)

				foreach {procname cname} $state(procs) {
					tcc command $procname $cname
				}
			}
			"dll" {
				append state(code) "int [string totitle $state(package)]_Init(Tcl_Interp *interp) \{\n"
				append state(code) "#ifdef USE_TCL_STUBS\n"
				append state(code) "  if (Tcl_InitStubs(interp, \"8.4\" , 0) == 0L) \{\n"
				append state(code) "    return TCL_ERROR;\n"
				append state(code) "  \}\n"
				append state(code) "#endif\n"

				foreach {procname cname} $state(procs) {
					append state(code) "  Tcl_CreateObjCommand(interp, \"$procname\", $cname, NULL, NULL);"
				}

				append state(code) "Tcl_PkgProvide(interp, \"$state(package)\", \"0.0\");\n"
				append state(code) "  return(TCL_OK);\n"
				append state(code) "\}"

				tcc compile $state(code)

				tcc output_file $state(filename)
			}
		}

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

proc ::tcc4tcl::wrap {name adefs rtype {body "#"} {cname ""}} {
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
	if {$body ne "#"} {
		append code "static $rtype2 ${cname}([join $cargs {, }]) \{\n"
		append code $body
		append code "\}\n"
	} else {
		append code "#define $cname $name" "\n"
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
	foreach x $varnames {
		set t $types($x)

		switch -- $t {
			int - long - float - double - char* - Tcl_Obj* {
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
	#   wide
	switch -- $rtype {
		void - ok - int - long - float - double - wide {}
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

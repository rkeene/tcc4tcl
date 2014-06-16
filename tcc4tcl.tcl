# tcc.tcl - library routines for the tcc wrapper (Mark Janssen)

namespace eval tcc4tcl {
	variable dir 
	variable libs
	variable includes
	variable count
	variable command_count
	variable commands

	set dir [file dirname [info script]]
	if {[info command ::tcc4tcl] == ""} {
		catch { load {} tcc4tcl }
	}
	if {[info command ::tcc4tcl] == ""} {
		load [file join $dir tcc4tcl[info sharedlibextension]] tcc4tcl
	}

	set libs $dir/lib
	set includes $dir/include
	set count 0
	set command_count 0
	array set commands {}

	proc new {{output "memory"}} {
		variable dir
		variable count

		set handle tcc_[incr count]
		tcc4tcl $dir $output $handle

		return $handle
	}

	proc tclcommand {handle name ccode} {
		variable commands
		variable command_count

		set cname _tcc_tcl_command_[incr command_count]

		set code    {#include "tcl.h"}
		append code "\nint $cname(ClientData cdata,Tcl_Interp *interp,int objc,Tcl_Obj* CONST objv\[\]) \{"
		append code "\n$ccode"
		append code "\}"

		$handle compile $code

		set commands($handle,$name) $cname

		return
	}

	proc compile {handle} {
		variable commands

		foreach cmd [array names commands ${handle},*] {
			set cname $commands($cmd)
			set tclcommand [join [lrange [split $cmd ,] 1 end] {}]

			set handle [lindex [split $cmd ,] 0]

			$handle command $tclcommand $cname
		}

		return
	}
}

proc tcc4tcl::to_dll {code dll {libs {}}} {
	set handle [::tcc4tcl::new dll]
	foreach lib $libs {
		$handle add_library $lib
	}

	if {$::tcl_platform(platform) eq "windows"} {
		$handle define DLL_EXPORT {__declspec(dllexport)} 

		set f [open [file join $::tcc4tcl::dir lib dllcrt1.c]]
		$handle compile [read $f]
		close $f

		set f [open [file join $::tcc4tcl::dir lib dllmain.c]]
		$handle compile [read $f]
		close $f
	} else {
		$handle define DLL_EXPORT ""
	}

	$handle compile $code
	$handle output_file $dll

	rename $handle {}
}

proc ::tcc4tcl::Log {args} {
	# puts $args
}

proc ::tcc4tcl::reset {} {
	variable tcc
	set tcc(code)   ""
	set tcc(cfiles) [list]
	set tcc(tk) 0
}

# Custom helpers
proc ::tcc4tcl::checkname {n} {expr {[regexp {^[a-zA-Z0-9_]+$} $n] > 0}}
proc ::tcc4tcl::cleanname {n} {regsub -all {[^a-zA-Z0-9_]+} $n _}

proc ::tcc4tcl::ccode {code} {
	variable tcc

	Log "INJECTING CCODE"

	append tcc(code) $code \n
}

proc ::tcc4tcl::cc {code} {
	variable tcc

	if {![info exists tcc(cc)]} {
		set tcc(cc) [::tcc4tcl::new]
	}

	$tcc(cc) compile $code
}

#----------------------------------------------------------- New DLL API
namespace eval ::tcc4tcl::dll {}
proc ::tcc4tcl::dll {{name ""}} {
	variable count

	if {$name eq ""} {
		set name dll[incr count]
	}

	namespace eval ::tcc4tcl::dll::$name {
		variable code "#include <tcl.h>\n" ;# always needed
		variable cmds {}
	}

	proc ::$name {cmd args} "::tcc4tcl::dll::\$cmd $name \$args"
	return $name
}

proc ::tcc4tcl::dll::ccode {name argl} {
	append ${name}::code "\n" [lindex $argl 0]

	return
}

proc ::tcc4tcl::dll::cproc {name argl} {
	foreach {pname pargs rtype body} $argl break

	set code [::tcc4tcl::wrapCmd $pname $pargs $rtype cx_$pname $body]

	lappend ${name}::cmds $pname cx_$pname
	append ${name}::code "\n" $code

	return
}

proc ::tcc4tcl::dll::write {name argl} {
	set (-dir) .
	set (-code) "" ;# possible extra code to go into the _Init function
	set (-libs) ""
	set (-name) [string tolower $name]
	array set "" $argl

	append ${name}::code "\n" \
		[::tcc4tcl::wrapExport $(-name) [set ${name}::cmds] $(-code)]

	set outfile $(-dir)/$(-name)[info sharedlibextension]

	::tcc4tcl::to_dll [set ${name}::code] $outfile $(-libs)
}

#---------------------------------------------------------------------
proc ::tcc4tcl::wrap {name adefs rtype {body "#"}} {
	set cname c_[tcc4tcl::cleanname $name]
	set wname tcl_$name
	array set types {}
	set varnames {}
	set cargs {}
	set cnames {}  
	set cbody {}
	set code {}

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

	append code "#include <tcl.h>\n"
	if {[info exists tcc(tk)] && $tcc(tk)} {
		append code "#include <tk.h>\n"
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
		append cbody "rv = "
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

	return [list $code $cbody]
}

proc ::tcc4tcl::wrapCmd {tclname argl rtype cname body} {
	foreach {code cbody} [wrap $tclname $argl $rtype $body] break

	append code "\nstatic int $cname(ClientData cdata,Tcl_Interp *ip, int objc,Tcl_Obj* CONST objv\[\]) \{\n"
	append code "\n$cbody\n\}\n"

	return $code
}

proc ::tcc4tcl::wrapExport {name cmds {body ""}} {
	set code "DLL_EXPORT int [string totitle $name]_Init(Tcl_Interp *interp) \{\n"

	foreach {tclname cname} $cmds {
		append code "Tcl_CreateObjCommand(interp, \"$tclname\", $cname, NULL, NULL);\n"
	}

	append code $body
	append code "\nreturn TCL_OK;\n\}"

	return $code
}

#---------------------------------------------------------------------
proc ::tcc4tcl::cproc {name adefs rtype {body "#"}} {
	foreach {code cbody} [wrap $name $adefs $rtype $body] break

	::tcc4tcl::ccode $code

	uplevel 1 [list ::tcc4tcl::ccommand $name {dummy ip objc objv} $cbody]
}

#---------------------------------------------------------------------
proc ::tcc4tcl::cdata {name data} {
	# Extract bytes from data
	binary scan $data c* bytes

	set inittext "\n"
	set line ""
	set n 0
	set l 0
	foreach c $bytes {
		if {$n > 0} {
			append inittext ","
		}
		if {$l > 20} {
			append inittext "\n"
			set l 0
		}

		if {$l==0} {
			append inittext "  "
		}

		append inittext [format "0x%02X" [expr {$c & 0xff}]]
		incr n
		incr l
	}

	append inittext "\n"

	set count [llength $bytes]  

	set cbody ""
	append cbody "static unsigned char script\[$count\] = \{" "\n"
	append cbody $inittext
	append cbody "\};" "\n"

	append cbody "Tcl_SetByteArrayObj(Tcl_GetObjResult(ip), (unsigned char*) script, $count);\n"
	append cbody "return TCL_OK;" "\n"

	uplevel 1 [list tcc4tcl::ccommand $name {dummy ip objc objv} $cbody]

	return $name
}

#-------------------------------------------------------------------
proc ::tcc4tcl::ccommand {procname anames args} {
	variable tcc

	# Fully qualified proc name
	if {[string match "::*" $procname]} {
		# procname is already absolute
	} else {
		set nsfrom [uplevel 1 {namespace current}]    
		if {$nsfrom eq "::"} {
			set nsfrom ""
		}

		set procname "${nsfrom}::${procname}"
	}

	set v(clientdata) clientdata
	set v(interp)     interp
	set v(objc)       objc
	set v(objv)       objv

	set id 0

	foreach defname {clientdata interp objc objv} {
		if {[llength $anames] > $id} {
			set vname [lindex $anames $id]

			if {![checkname $vname]} {
				error "invalid variable name \"$vname\""
			}
		} else {
			set vname $defname
		}

		set v($defname) $vname

		incr id
	}

	set cname Cmd_N${id}_[cleanname $procname]
	set code ""

	if {[info exists tcc(tk)] && $tcc(tk)} {
		append code "\#include <tk.h>" "\n"
	}

	if {[info exists tcc(code)]} {
		append code $tcc(code)
		append code "\n"
	}
	set tcc(code) ""

	append code "int $cname (ClientData $v(clientdata),Tcl_Interp *$v(interp),"
	append code "int $v(objc),Tcl_Obj *CONST $v(objv)\[\]) {" "\n"
	append code [lindex $args end] "\n"
	append code "}" "\n"

	if {[catch {
		uplevel 1 [list tcc4tcl::cc $code]
	} err]} {
		unset tcc(cc)
		tcc4tcl::reset

		return -code error $err
	}

	Log "CREATING TCL COMMAND $procname / $cname"
	uplevel 1 [list $tcc(cc) command $procname $cname]

	unset tcc(cc) ;# can't be used for compiling anymore
	tcc4tcl::reset
}

proc ::tcc4tcl::tk {args} {
	variable tcc
	set tcc(tk) 1
}

::tcc4tcl::reset
namespace eval tcc4tcl {namespace export cproc ccode cdata}

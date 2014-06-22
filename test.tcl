#! /usr/bin/env tclsh

lappend auto_path [lindex $argv 0]
package require tcc4tcl

tcc4tcl::cproc test {int i} int { return(i+42); }
tcc4tcl::cproc test1 {int i} int { return(i+42); }
tcc4tcl::cproc ::bob::test1 {int i} int { return(i+42); }

# This will fail
catch {
	tcc4tcl::cproc test2 {int i} int { badcode; }
}

# This should work
tcc4tcl::cproc test3 {int i} int { return(i+42); }

# Multiple arguments
tcc4tcl::cproc add {int a int b} int { return(a+b); }

# Add external functions
tcc4tcl::cproc mkdir {Tcl_Interp* interp char* dir} ok {
	int mkdir_ret;
	mkdir_ret = mkdir(dir);

	if (mkdir_ret != 0) {
		Tcl_SetObjResult(interp, Tcl_NewStringObj("failed", -1));
		return(TCL_ERROR);
	};
	return(TCL_OK);
}

# Return error on NULL
tcc4tcl::cproc test4 {int v} char* {
	if (v == 1) {
		return("ok");
	}

	return(NULL);
}

puts [test 1]
puts [test1 1]
puts [test3 1]
puts [::bob::test1 1]
puts [add [test 1] 1]
puts [test4 1]

catch {
	puts [mkdir "/"]
} err
if {$err != "failed"} {
	error "\[mkdir\] did not return the expected error"
}

catch {
	set v 0
	puts [test4 0]
	set v 1
} err
if {$err != "" || $v == 1} {
	error "\[test4\] did not return the expected error"
}

# New API
set handle [tcc4tcl::new]
$handle cproc test5 {int i} int { return(i + 42); }
if {[$handle code] == ""} {
	error "[list $handle code] did not give code output"
}
$handle cproc test6 {int i} int { return(i + 42); }
$handle go
puts [test5 1]
puts [test6 1]

set handle [tcc4tcl::new]
$handle ccode {const char *curl_version(void);}
$handle cproc curl_version {} char*
$handle add_library_path /usr/lib64
$handle add_library_path /usr/lib
$handle add_library curl
$handle go
puts [curl_version]

set handle [tcc4tcl::new]
$handle delete

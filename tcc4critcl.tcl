#! /usr/bin/env tclsh

package require tcc4tcl

namespace eval ::critcl {}

proc ::critcl::_allocateHandle {} {
	if {![info exists ::critcl::handle]} {
		set ::critcl::handle [::tcc4tcl::new]
	}

	return $::critcl::handle
}

apply {{} {
	foreach {proc args} {
		ccode code
		ccommand {command argList body}
	} {
		set argslist ""
		foreach arg $args {
			append argslist " \$$arg"
		}
		set argslist [string range $argslist 1 end]

		proc ::critcl::${proc} $args [string map [list @@PROC@@ $proc @@ARGSLIST@@ $argslist] {
			set handle [::critcl::_allocateHandle]

			uplevel #0 [list $handle @@PROC@@ @@ARGSLIST@@]
		}]
	}
}}

proc ::critcl::ccode {code} {
	set handle [::critcl::_allocateHandle]

	tailcall $handle ccode $code
}

proc ::critcl::_go {handle} {
	$handle go

	if {$handle != $::critcl::handle} {
		error "out of sync"
	}

	unset -nocomplain ::critcl::handle
}

proc ::critcl::ccommand {command argList body} {
	set handle [::critcl::_allocateHandle]

	set command [::tcc4tcl::lookupNamespace $command]

	$handle ccommand $command $argList $body

	set body {
		set args [uplevel 1 set args]

		::critcl::_go $handle

		tailcall $command {*}$args
	}

	proc $command args [list apply [list {handle command} $body] $handle $command]
}

proc ::critcl::cproc {command argList resultType body} {
	set handle [::critcl::_allocateHandle]

	set command [::tcc4tcl::lookupNamespace $command]

	$handle cproc $command $argList $resultType $body

	set body {
		set args [uplevel 1 set args]

		::critcl::_go $handle


		tailcall $command {*}$args
	}

	proc $command args [list apply [list {handle command} $body] $handle $command]
}

proc ::critcl::cheaders {args} {
	set handle [::critcl::_allocateHandle]

	foreach arg $args {
		unset -nocomplain includeDir

		if {[info exists nextArg]} {
			set thisArg $nextArg
			unset nextArg
			set $thisArg $arg
		}

		switch -glob -- $arg {
			"-I" {
				set nextArg "includeDir"
			}
			"-I*" {
				set includeDir [string trim [string range $arg 2 end]]
			}
		}

		if {[info exists includeDir]} {
			$handle add_include_path [file join $::critcl::dir $includeDir]
			unset includeDir
			continue
		}

		foreach header [glob -tails -nocomplain -directory $::critcl::dir -- $arg] {
			$handle add_include_path [file join $::critcl::dir [file dirname $header]]
			$handle ccode "#include \"$header\""
		}
	}
}

proc ::critcl::csources {file} {
	set handle [::critcl::_allocateHandle]

	if {![info exists ::critcl::csources]} {
		set ::critcl::csources [list]
	}

	# Locate file relative to current script
	foreach file [glob -nocomplain -directory $::critcl::dir -- $file] {
		set fullFile [file normalize $file]
		if {$fullFile in $::critcl::csources} {
			continue
		}
		lappend ::critcl::csources $fullFile

		set fd [open $file]
		$handle ccode [read $fd]
		close $fd
	}
}

proc ::critcl::cflags args {
	set handle [::critcl::_allocateHandle]
	$handle process_command_line [join $args " "]
}

proc ::critcl::ldflags args {
	set handle [::critcl::_allocateHandle]
	$handle process_command_line [join $args " "]
}

package provide critcl 0

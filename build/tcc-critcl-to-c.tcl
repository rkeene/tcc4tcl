#! /usr/bin/env tclsh

#package require -exact critcl 0
catch {
	source ../tcc4tcl.tcl
}
package provide tcc4tcl 0
catch {
	source ../tcc4critcl.tcl
} err

# Emit a library by default
set packageName "PACKAGENAME"
set packageVersion "0"
set outputMode "library"
proc ::critcl::_allocateHandle {} {
        if {[info exists ::critcl::handle]} {
        	return $::critcl::handle
	}

	switch -exact $::outputMode {
		"library" {
	               	set ::critcl::handle [::tcc4tcl::new $::packageName [list $::packageName $::packageVersion]]
		}
		"application" {
	               	set ::critcl::handle [::tcc4tcl::new $::packageName]
		}
		"direct" {
	               	set ::critcl::handle [::tcc4tcl::new]
		}
	}

       	return $::critcl::handle
}

# Build up C code from arguments
foreach script $argv {
	if {[info exists nextParam]} {
		set thisParam $nextParam
		unset nextParam
		switch -exact -- $thisParam {
			"--package" {
				set ::packageName [lindex $script 0]
				set ::packageVersion [lindex $script 1]

				if {$::packageVersion eq ""} {
					set ::packageVersion "@PACKAGEVERSION@"
				}
				continue
			}
			"--mode" {
				set ::outputMode $script
				continue
			}
			default {
				puts stderr "Internal error: incomplete nextParam $nextParam"
				exit 1
			}
		}
	}

	switch -exact -- $script {
		"--package" - "--mode" {
			set nextParam $script
			continue
		}
		"--help" {
			puts {Usage: tcc-critcl-to-c.tcl [--package <nameAndVersion>] [--mode {library|application|direct}] <tclScripts...>}
			exit 0
		}
	}

	set ::critcl::dir [file dirname $script]
	source $script

	if {[info exists ::critcl::handle]} {
		$::critcl::handle add_include_path $::critcl::dir
	}
}

# If no Critcl functions have been used, do nothing
if {![info exists ::critcl::handle]} {
	exit 0
}

set map [list]
if {$packageVersion eq "@PACKAGEVERSION@"} {
	catch {
		set packageVersion 0
		set packageVersion [package present $packageName]
	}

	lappend map @PACKAGEVERSION@ $packageVersion
}

# Emit the resulting C code
puts [string map $map [$::critcl::handle code]]

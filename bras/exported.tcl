########################################################################
#
# This file is part of bras, a program similar to the (in)famous
# `make'-utitlity, written in Tcl.
#
# Copyright (C) 1996, 1997, 1998, 1999
#                    Harald Kirsch, (kir@iitb.fhg.de)
#                    Fraunhofer Institut IITB
#                    Fraunhoferstr. 1
#                    76131 Karlsruhe
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
#
# $Revision: 1.5 $, $Date: 2000/03/05 12:37:28 $
########################################################################
## source version and package provide
source [file join [file dir [info script]] .version]

##
## This file contains commands intended to be used in brasfiles
## (besides rule-commands which are defined elsewhere).
##

namespace eval ::bras {
  namespace export configure getenv searchpath include consider dumprules
}

########################################################################
#
# Set or reset some flags controlling bras's operation
#
proc ::bras::configure {option {on {1}} } {
  variable Opts

  switch -exact -- $option {
    -d -
    -s -
    -k -
    -v {
      set Opts($option) $on
    }
    -n {
      set Opts($option) $on
      set Opts(-v) $on
    }
    -ve {
      set Opts($option) $on
      if {$on} {
	rename exec ::bras::exec_orig
	rename ::bras::verboseExec ::exec
      }
    }
    default {
      return -code error "unknown options $option"
    }
  }
}    
########################################################################
##
## This is useful to set global variables in a way that they can be
## overridden by the environment or on the command line. Typical
## candidates are CC, prefix and the like.
##
## Typical use:
## getenv prefix /usr/local
##
proc ::bras::getenv {_var {default {}} } {
  upvar $_var var
  global env
  if {[info exist env($_var)]} {
    set var $env($_var)
  } else {
    set var $default
  }
}
########################################################################
##
## Every directory with its own brasfile has its own search path.
## Without arguments, the current path is unchanged.
## The new path is always returned.
##
proc ::bras::searchpath { {p {never used}} } {
  variable Searchpath

  if {[llength [info level 0]]==2} {
    ## something was explicitly passed in
    if {[llength $p]} {
      set Searchpath([pwd]) $p
    } else {
      unset Searchpath([pwd])
      return {}
    }
  } elseif {![info exist Searchpath([pwd])]} {
    return {}
  }

  return $Searchpath([pwd])
}
########################################################################
##
## include
##   an alias for `source', however we take care to not source any
##   file more than once.
##  
##   If the `name' starts with an `@' it must be a directory. In that
##   case, the $Brasfile of that directory is sourced in the same way
##   as if an `@'-target had let to that directory.
##
##   If the `name' does not start with `@', it must be the name of an
##   existing readable file. This one is simpy sourced in.
##
proc ::bras::include {name} {
  variable Known
  
  if [string match @* $name] {
    cd [followTarget [file join $name .]]
    return
  }

  ## To be compatible with followTarget, we first have to move to the
  ## destination directory to get the correct answer from [pwd]. _NO_,
  ## just stripping the directory part from $name is useless, because
  ## it may contain relative parts and parts leading through one or
  ## more soft-links.
  set dir [file dir $name]
  set file [file tail $name]

  set oldpwd [pwd]
  if [catch "cd $dir" msg] {
    set err "bras: include of `$name' tried in directory `$oldpwd'"
    append err " leads to non-existing directory `$dir'"
    puts stderr $err
    exit 1
  }
  set pwd [pwd]
  cd $oldpwd

  if {[info exist Known([file join $pwd $file])]} return
  set Known([file join $pwd $file]) 1

  gobble $name
}
########################################################################
#
# Consider all given targets in turn. Targets may start with an @ and
# a directory part.
#
# RETURN:
# a list of ones and zeros denoting whether a target was just made (or
# during this run of bras) or not.
#
# ERRORS:
# If a target cannot be made, an error is returned. If
# bras-option -k is set, consider continues to the end of the list
# after an error but still returns an error in the end.
#
proc ::bras::consider {targets} {
  variable Opts
  variable Indent

  if {![llength $targets]} {return {}}
  
  if {$Opts(-d)} {
    set caller [info level -1]
    set procname [uplevel namespace which [lindex $caller 0]]
    if {![string match ::bras::* $procname]} {
      dmsg "=> on behalf of `$caller':"
      append Indent "  "
      set msg 1
    }
  }

  set res {}
  set err {}
  foreach t $targets {
    if {[catch {::bras::considerOne $t} r]} {
      append err "\n" $r
      if {!$Opts(-k)} break
    } else {
      lappend res $r
    }
  }

  if {[info exist msg]} {
    set Indent [string range $Indent 2 end]
    dmsg "<= done"
  }

  if {"$err"!=""} {
    return -code error $err
  } else {
    return $res
  }
}
########################################################################
proc ::bras::dumprules {} {
  variable Known
  variable Prule
  variable Rule

  puts "\#\# bras dumping rules"
  puts "\#\# known files are:"
  foreach x [array names Known] {
    puts "\#\#   `$x'"
  }
  puts ""

  puts "\#\# pattern rules:"
  foreach id $Prule(all) {
    set gd $Prule($id,gdep)
    puts -nonewline "proc $gd {[info args ::bras::gendep::$gd]} {"
    puts -nonewline "[info body ::bras::gendep::$gd]"
    puts "}"
    puts "PatternMake $Prule($id,trexp) $gd {"
    puts "  $Prule($id,bexp)"
    puts -nonewline "} {"
    puts "  $Prule($id,cmd)}"
    puts ""
  }

  puts "\#\# rules:"
  foreach id $Rule(all) {
    puts "Make $Rule($id,targ) {"
    foreach {t d b} $Rule($id,bexp) {
      puts "$b"
    }
    puts "} {"
    puts "$Rule($id,cmd)"
    puts "}"
  }
}
########################################################################

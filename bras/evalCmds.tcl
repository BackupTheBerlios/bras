########################################################################
#
# This file is part of bras, a program similar to the (in)famous
# `make'-utitlity, written in Tcl.
#
# Copyright (C) 1996 Harald Kirsch, (kir@iitb.fhg.de)
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
########################################################################

proc bras.unknown args {
  global brasOpts auto_noexec

  #puts "unknown: `$args'"

  set args [eval concat $args]
  #puts "would exec $args"

  ## First let the original `unknown' try to do something useful, but
  ## don't let it execute external commands.
  set auto_noexec 1
  if {![catch "unknown.orig $args" res]} {
    unset auto_noexec
    return $res
  }
  unset auto_noexec

  ## There seems to be a change in the return value of auto_execok
  ## somewhere between 7.4 and 7.6. I try to exploit both versions.
  set name [lindex $args 0]
  set tmp [auto_execok $name]
  if {""=="$tmp" || "0"=="$tmp"} {
    return -code error \
	"command not found when executing `$args'"
  }

  if {$brasOpts(-N)} {
    puts stdout $args
    return {}
  }
  
  if {!$brasOpts(-ss)} {
    ## not super-silent
    if {!$brasOpts(-s)} {
      puts stdout $args
    } else {
      puts -nonewline stdout .
    }
  }
  
  #    return [uplevel exec <@stdin 2>@stderr >@stdout $args]
  return [eval exec <@stdin 2>@stderr >@stdout $args]

}
########################################################################
proc bras.evalCmds {cmds} {
  global brasOpts errorInfo

  rename unknown unknown.orig
  rename bras.unknown unknown

  foreach cmd $cmds {
    if { [string match @cd* $cmd] } {
      set newcwd [string trim [lindex $cmd 1]]
      if { "$newcwd"=="[pwd]" } continue
      set cmd [string range $cmd 1 end]
      if {!$brasOpts(-s) && !$brasOpts(-ss)} {
	puts stdout $cmd
      }
      eval $cmd
      continue
    }

    if { "@"==[string index $cmd 0] } {
      set cmd [string range $cmd 1 end]
    }
    if $brasOpts(-v) {
      regsub -all "\n" [string trim $cmd "\n"] "\n" c
      puts "$c"
    }
    
    if $brasOpts(-n) continue

    ## The command is finally executed with uplevel.
    if [catch "uplevel #0 {$cmd}" msg] {
      puts stderr \
	  "\nbras: a rule-command failed to execute and said:\n"
      puts stderr $errorInfo
      exit 1
    }
  }
  rename unknown bras.unknown
  rename unknown.orig unknown
}

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

proc ::bras::newNS {} {
  variable nsid
  
  incr nsid
  return "::bras::s$nsid"
}
########################################################################
proc ::bras::unknown args {
  global brasOpts

  #puts "unknown: `$args'"

  set args [eval concat $args]
  #puts "would exec $args"

  ## First let the original `unknown' try to do something useful, but
  ## don't let it execute external commands.
  set ::auto_noexec 1
  set code [catch {uplevel 1 ::bras::unknown.orig $args} res]
  unset ::auto_noexec
  if {!$code} { ;# the original unknown worked
    return $res
  }

  ## If we are here, the unknown.orig did not work we will proceed on
  ## our own, but only for executables.
  set tmp [auto_execok [lindex $args 0]]
  if {![string length $tmp]} {
    return -code error $res
  }

  if {$brasOpts(-ve)} {
    puts $args
    set exec bras.exec
  } else {
    set exec exec
  }
  if {[catch {eval $exec <@stdin 2>@stderr >@stdout $args} msg] } {
    return -code error $msg
  }

}
########################################################################
proc ::bras::invokeCmd {rid Target Deps Trigger} {

  global brasRule brasOpts brasIndent

  ## find the command to execute
  set cmd $brasRule($rid,cmd)
  if {""=="$cmd"} {
    puts -nonewline stderr \
	"bras(warning) in `[pwd]': no command found to make `$Target' "
    puts stderr "from `$Deps' (hope that's ok)"
    return 1
  }
  set brasRule($rid,run) 1


  if {"[info command ::bras::unknown.orig]"=="::bras::unknown.orig"} {
    ## Someone called `consider' within a rule's command
    set haveUnknown 1
  } else {
    set haveUnknown 0
    rename ::unknown ::bras::unknown.orig
    rename ::bras::unknown ::unknown
  }
  
  ## set up the context for the command
  set nspace [newNS]
  namespace eval $nspace [list variable target $Target]
  namespace eval $nspace [list variable targets $brasRule($rid,targ)]
  namespace eval $nspace [list variable trigger $Trigger]
  namespace eval $nspace [list variable deps $Deps]

  if {$brasOpts(-v)} {
    namespace eval $nspace {
      puts "\# -- running command --"
      puts "\#  target = `$target'"
      puts "\# targets = `$targets'"
      puts "\# trigger = `$trigger'"
      puts "\#    deps = `$deps'"
    }
    puts [string trim $cmd "\n"]
  }
 
  if {!$brasOpts(-n)} {

    if {!$brasOpts(-v) && !$brasOpts(-ve) &&
	!$brasOpts(-d) && !$brasOpts(-s)} {
      puts  "\# making `$Target'";
    }

    set wearehere [pwd]

    set script [list uplevel \#0 $cmd]
    namespace eval $nspace "variable bras.cmd {$cmd}"
    namespace eval $nspace {
      if {[catch ${bras.cmd} msg]} {
	global errorInfo
	puts stderr $errorInfo
	puts stderr "    while making target `$target' with command"
	puts stderr "{${bras.cmd}}"
	exit 1
      }
    }
	
    cd $wearehere
    namespace delete $nspace
  }

  if {!$haveUnknown} {
    rename ::unknown ::bras::unknown
    rename ::bras::unknown.orig ::unknown
  }

  return 1
}

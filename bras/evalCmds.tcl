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
## source version and package provide
source [file join [file dir [info script]] .version]

########################################################################
#
# REMEMBER: This proc looks like it will work insides namespace
# ::bras. However when it is actually called, it will have been
# renamed to ::unknown. See invokeCmd for the details.
#
proc ::bras::unknown args {

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

#   if {$::bras::Opts(-ve)} {
#     puts $args
#     set exec ::bras::exec_orig
#   } else {
#     set exec exec
#   }
  if {[catch {eval exec <@stdin 2>@stderr >@stdout $args} msg] } {
    return -code error $msg
  }

}
########################################################################
proc ::bras::invokeCmd {rid Target Deps Trigger} {
  variable Rule
  variable Opts

  ## find the command to execute
  set cmd $Rule($rid,cmd)
  if {""=="$cmd"} {
    puts -nonewline stderr \
	"bras(warning) in `[pwd]': no command found to make `$Target' "
    puts stderr "from `$Deps' (hope that's ok)"
    return 1
  }
  set Rule($rid,run) 1


  if {"[info command ::bras::unknown.orig]"=="::bras::unknown.orig"} {
    ## Someone called `consider' within a rule's command
    set haveUnknown 1
  } else {
    set haveUnknown 0
    rename ::unknown ::bras::unknown.orig
    rename ::bras::unknown ::unknown
  }
  
  ## Set up a namespace within which the command will be executed. The 
  ## main reason for this is that we want to have the variables
  ## targets, target, trigger and deps to be unique for this
  ## command. They cannot be global because the command may call
  ## `consider', thereby invoking another command which also wants to
  ## have these variables.
  set nspace "::bras::s[nextID]"
  namespace eval $nspace [list variable target $Target]
  namespace eval $nspace [list variable targets $Rule($rid,targ)]
  namespace eval $nspace [list variable trigger $Trigger]
  namespace eval $nspace [list variable deps $Deps]

  if {$Opts(-v)} {
    namespace eval $nspace {
      puts "\# -- running command --"
      puts "\#  target = `$target'"
      puts "\# targets = `$targets'"
      puts "\# trigger = `$trigger'"
      puts "\#    deps = `$deps'"
    }
    puts [string trim $cmd "\n"]
  }
 
  if {!$Opts(-n)} {

    if {!$Opts(-v) && !$Opts(-ve) &&
	!$Opts(-d) && !$Opts(-s)} {
      puts  "\# making `$Target'";
    }

    set wearehere [pwd]

    ## The following construct runs the command within its own
    ## namespace on stacklevel #0. Well, in fact it ends up on
    ## stacklevel #1 because [namespace] accounts for on level of
    ## stack. 
    namespace eval $nspace [list variable c $cmd]
    uplevel \#0 namespace eval $nspace {{
      if {[catch "unset c; $c" msg]} {
	global errorInfo
	puts stderr $errorInfo
	puts stderr "    while making target `$target' with command"
	exit 1
      }
    }}
	
    cd $wearehere
    namespace delete $nspace
  }

  if {!$haveUnknown} {
    rename ::unknown ::bras::unknown
    rename ::bras::unknown.orig ::unknown
  }

  return 1
}

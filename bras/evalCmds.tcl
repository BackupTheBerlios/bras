########################################################################
#
# This file is part of bras, a program similar to the (in)famous
# `make'-utitlity, written in Tcl.
#
# Copyright (C) 1996--2000 Harald Kirsch
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
  if {!$code} { 
    # the original unknown worked
    return $res
  }

  ## If we are here, the unknown.orig did not work we will proceed on
  ## our own, but only for executables.
  set tmp [auto_execok [lindex $args 0]]
  if {![string length $tmp]} {
    return -code error $res
  }

  if {[catch {eval exec <@stdin >@stdout $args} msg] } {
    return -code error $msg
  }
  #eval exec <@stdin 2>@stderr >@stdout $args
}
########################################################################
proc ::bras::invokeCmd {rid Target pstack} {
  variable Namespace
  variable Rule
  variable Opts

  ## find the command to execute
  set cmd $Rule($rid,cmd)
  if {""=="$cmd"} {
    foreach {x y bexp} $Rule($rid,bexp) {
      lappend l $bexp
    }
    set l [join $l "|"]
    append msg \
	"bras(warning) in `[pwd]': no command found to " \
	"make `$Target' for `$l' (hope that's ok)"
    report warn $msg
    return
  }
  
  ## silently ignore commands which contain nothing but .relax.,
  ## possibly surrouned by whitespace.
  if {".relax."=="[string trim $cmd]"} return

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
  ## targets, target, and those from $values to be unique for this
  ## command. They cannot be global because the command may call
  ## `consider', thereby invoking another command which also wants to
  ## have these variables.

  # The namespace in which the command is run is bound to the current
  # directory. We now set up some additional variables in that
  # namespace, namely target, targets and whatever was communicated by
  # the predicates in the namespace given by $pstack. Because a
  # command may call [consider] recursively, we have to backup and
  # later restore the variables we are going to overwrite.
  set currentDir [pwd]
  set dirns $Namespace($currentDir)

  set ptails {}
  foreach x [info vars [set pstack]::*] {
    lappend ptails [namespace tail $x]
  }
  vbackup store [concat $ptails {target targets}] [set dirns]::

  namespace eval $dirns [list variable target $Target]
  namespace eval $dirns [list variable targets $Rule($rid,targ)]
  foreach ptail $ptails {
    catch {unset [set dirns]::$ptail}
    ## Sorry, currently only scalars are supported, mainly because
    ## $pstack should normally only contain scalars (see
    ## initialization of vars in installPredicate)
    set [set dirns]::$ptail [set [set pstack]::$ptail]
  }

  if {$Opts(-v)} {
    report -v "\# -- running command --"
    foreach name [info vars [set dirns]::*] {
      set tail [namespace tail $name]
      if {[string match reason $tail]} continue
      report -v "\# $tail = `[set $name]'"
    }
    report -v  [string trim $cmd \n]
  }
 
  if {!$Opts(-n)} {

    if {!$Opts(-v) && !$Opts(-d) && !$Opts(-s)} {
      report norm "\# making `$Target'"
    }

    ## The following construct runs the command within its own
    ## namespace on stacklevel #0. Well, in fact it ends up on
    ## stacklevel #1 because [namespace] accounts for one level of
    ## stack. 
    set script [list catch $cmd msg]
    set script [list namespace eval $dirns $script]
    set result [uplevel \#0 $script]
    cd $currentDir
    if {$result} {
      ::bras::trimErrorInfo
      append ::errorInfo \
	  "\n    while making target `$Target' in `[pwd]'---SNIP---"
      return -code error -errorinfo $::errorInfo
    }
  }

  vrestore store

  if {!$haveUnknown} {
    rename ::unknown ::bras::unknown
    rename ::bras::unknown.orig ::unknown
  }

}

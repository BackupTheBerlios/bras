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
# $Revision: 1.1 $, $Date: 1997/04/20 07:05:13 $
########################################################################

########################################################################
##
## Check whether the target needs to be rebuilt.
##
## RETURN
## 1 -- it was decided to rebuild the target
## 0 -- the target does not need to be rebuilt
##
## If it is decided that the target needs to be rebuild, the commands
## necessary are appended to the first variable with name brasCmdlist
## that is found on the stack, i.e. in an (indirectly) calling
## procedure. This method was choosen so that user-defined rules need
## not pass the command-list back and forth when calling this function
## or when called by this function. (Search for `level' to find the
## place where it is done.)
##
proc bras.Consider {target} {
  global brasRules argv0 brasOpts brasConsidering
  global brasIndent

  ## change dir, if target starts with `@'
  if {[string match @* $target]} {
    set t [string range $target 1 end]
    set keepPWD [pwd]
    set dir [file dir $t]
    if [catch "cd $dir" msg] {
      puts stderr \
     "$argv0: cannot change from `[pwd]' to `$dir' for `$target'"
      exit 1
    }
    set target [file tail $t]

  } else {
    set keepPWD .
  }

  ## check, if this target was handled already along another line of
  ## reasoning 
  if [info exist brasRules($target,[pwd],done)] {
    if $brasOpts(-d) {
      bras.dmsg $brasIndent "have seen `$target' in `[pwd]' already"
    }
    set pwd [pwd]
    cd $keepPWD
    return $brasRules($target,$pwd,done)
  }


  ## check for dependeny loops
  if {[info exist brasConsidering($target,[pwd])]} {
    puts stderr \
	"$argv0: dependency loop detected for `$target' in `[pwd]'"
    exit 1
  }
  set brasConsidering($target,[pwd]) 1

  ## describe line of reasoning
  if $brasOpts(-d) {
    bras.dmsg $brasIndent "considering `$target' in `[pwd]'"
  }


  ## handle targets without rule
  if {![info exist brasRules($target,[pwd])] } {
    bras.lastMinuteRule $target $brasIndent
  }

  ## Check if there is still no rule available
  if {![info exist brasRules($target,[pwd])] } {
    ## If the target exists as a file, this is ok
    if [file exist $target] {
      if $brasOpts(-d) {
	bras.dmsg $brasIndent \
	    "`$target' is ok, file exists and has no rule"
      }
      set brasRules($target,[pwd],done) 0
      unset brasConsidering($target,[pwd])
      cd $keepPWD
      return 0
    } else {
      puts stderr "$argv0: no rule to make target `$target' in `[pwd]'"
      exit 1
    }
  }


  ## Make the list of dependencies without leading @
  set deps $brasRules($target,[pwd],deps)
  set pureDeps {}
  foreach dep $deps {
    if {[string index $dep 0]=="@"} {
      lappend pureDeps [string range $dep 1 end]
    } else {
      lappend pureDeps $dep
    }
  }

  ## Call the rule for the target
  set newer {}
  set rule $brasRules($target,[pwd])
  append brasIndent "  "
  set brasCmdlist {}
  set reason [Check.$rule $target $deps newer]	;###<<<- HERE
  set brasIndent [string range brasIndent 2 end]

  ## Evaluate the reason of rebuilding, if any
  if {"$reason"==""} {
    set brasRules($target,[pwd],done) 0
    if { $brasOpts(-d) } {
      bras.dmsg $brasIndent "`$target' in `[pwd]' is up-to-date"
    }

  } else {
    set brasRules($target,[pwd],done) 1

    ## copy local command-list to the command list of the (indirectly)
    ## calling consider-proc. This requires searching up the stack for
    ## the variable brasCmdlist.
    for {set l [expr [info level]-1]} {$l>=0} {incr l -1} {
      upvar #$l brasCmdlist cmdlist
      if {[info exist cmdlist]} break
    }
    if {$l<0} {
      puts "BANG BANG BANG! This cannot happen. Must die."
      exit 1
    }
    eval lappend cmdlist $brasCmdlist

    ## Add the command for this target to the list of commands. We go
    ## right through cmdlist here, which is somewhere up the stack,
    ## since it does not make sense to set the local brasCmdlist first.
    set cmd $brasRules($target,[pwd],cmd)
    if { ""=="$cmd" } {
      ## try to find a suitable suffix command
      set cmd [bras.defaultCmd $target $pureDeps reason]
    }
    if {[llength $cmd]} {
      lappend cmdlist "@cd [pwd]"
      lappend cmdlist "@set target $target"
      lappend cmdlist "@set trigger \"$newer\""
      lappend cmdlist "@set deps \"$pureDeps\""
      lappend cmdlist $cmd 
    }

    if { $brasOpts(-d) } {
      regsub -all "\n" $reason "\n    " reason
      bras.dmsg $brasIndent \
	  "`$target' in `[pwd]' remade because$reason"
    }
  }


  ## clean up and return
  unset brasConsidering($target,[pwd])
  set pwd [pwd]
  cd $keepPWD
  return $brasRules($target,$pwd,done)
}

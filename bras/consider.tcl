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
# $Revision: 1.2 $, $Date: 1997/04/26 19:57:31 $
########################################################################

########################################################################
##
## bras.dmsg
##
proc bras.dmsg {dind msg} {
  regsub -all "\n" $msg "\n$dind" msg
  puts $dind$msg
}
########################################################################
##
## Check whether the target needs to be rebuilt.
##
## RETURN
## 0: no need to make target
## 1: target will be made
## -1: target needs to be made, but don't know how
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
  global brasRule brasTinfo argv0 brasOpts brasConsidering
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
  if [info exist brasTinfo($target,[pwd],done)] {
    if $brasOpts(-d) {
      bras.dmsg $brasIndent "have seen `$target' in `[pwd]' already"
    }
    set pwd [pwd]
    cd $keepPWD
    return $brasTinfo($target,$pwd,done)
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
  if { ![info exist brasTinfo($target,[pwd],rule)] } {
    bras.lastMinuteRule $target $brasIndent
  }

  ## Check if there is still no rule available
  if {![info exist brasTinfo($target,[pwd],rule)] } {
    if [file exist $target] {
      ## The target exists as a file, this is ok.
      if $brasOpts(-d) {
	bras.dmsg $brasIndent \
	    "`$target' is ok, file exists and has no rule"
      }
      set brasTinfo($target,[pwd],done) 0
      set res 0
    } else {
      ## The file does not exist, so we decide it must be remade, but
      ## we don't know how.
      if $brasOpts(-d) {
	bras.dmsg $brasIndent \
	    "`$target' does not exist and has no rule"
      }
      set brasTinfo($target,[pwd],done) -1
      set res -1
    }
    unset brasConsidering($target,[pwd])
    cd $keepPWD
    return $res
  }


  ## Make the list of dependencies without leading @
  set deps $brasTinfo($target,[pwd],deps)
  set pureDeps {}
  foreach dep $deps {
    if {[string index $dep 0]=="@"} {
      lappend pureDeps [string range $dep 1 end]
    } else {
      lappend pureDeps $dep
    }
  }

  ## Call the rule for the target
  set ri $brasTinfo($target,[pwd],rule)
  set rule $brasRule($ri,type)
  set newer {}
  append brasIndent "  "
  set brasCmdlist {}
  set reason ""
  set res [Check.$rule $target $deps newer reason]	;###<<<- HERE
  set brasIndent [string range $brasIndent 2 end]
  #puts "$target ... $reason `$res'"

  ## Evaluate the result
  if {$res==-1} {
    if { $brasOpts(-d) } {
      #regsub -all "\n" $reason "\n    " reason
      set msg "cannot make `$target' in `[pwd]'"
      append msg " because\n    one or more dependencies cannot be made"
      bras.dmsg $brasIndent $msg
    }
    set brasTinfo($target,[pwd],done) $res
    
  } elseif {$res==0} {
    if { $brasOpts(-d) } {
      bras.dmsg $brasIndent "`$target' in `[pwd]' is up-to-date"
    }
    set brasTinfo($target,[pwd],done) $res
    
  } else {
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
    set cmd $brasRule($ri,cmd)
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

    ## Mark all targets connected to this rule is done
    foreach t $brasRule($ri,targ) {
      set brasTinfo($t,[pwd],done) 1
    }

    if { $brasOpts(-d) } {
      regsub -all "\n" $reason "\n    " reason
      bras.dmsg $brasIndent \
	  "`$target' in `[pwd]' remade because$reason"
    }
  }

  ## finish up and return
  unset brasConsidering($target,[pwd])
  cd $keepPWD
  return $res
}

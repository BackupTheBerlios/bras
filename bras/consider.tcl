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
# $Revision: 1.3 $, $Date: 1997/04/30 17:35:28 $
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
## Make the list of dependencies without leading @
proc bras.pureDeps {deps} {
  set pureDeps {}
  foreach dep $deps {
    if {[string match @* $dep]} {
      lappend pureDeps [string range $dep 1 end]
    } else {
      lappend pureDeps $dep
    }
  }
  return $pureDeps
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
## How a target is considered:
## Suppose target t in directory d is considered. The the following
## steps are performed:
## o Run the predicates listed in brasTinfo($t,$d,pred) one after
##   another. Three cases are possible:
##   1) All predicates return 0, i.e. the target is ok. The 0 is
##      returned.
##   2) Some predicates return -1, but none returns 1, i.e. the
##      targets should be made, but some of its dependencies are not
##      available or cannot be made. In this case, -1 is returned.
##   3) At least one predicate returns 1. Then, the following
##      predicates on the list are ignored, and instead the steps
##      described below are executed.
## o The command-index ci is looked up in brasTinfo($t,$d,cmd)
## o The dependencies of the predicate which returned 1 are
##   (temporarily added to the prerequisites of the command.
## o All prerequisites of the command are all considered. Two cases
##   are then possible:
##   1) One prerequisite must be made, but cannot, i.e. we receive
##      -1. Then -1 is immediately returned.
##   2) All prerequisites are ok or can be made. Then the command is
##      added to the list of commands to be executed and all targets
##      stored for the command are marked in their done-field with 1. 
##      Finally 1 is returned.
##
##
proc bras.Consider {target} {
  global brasCmd brasTinfo argv0 brasOpts brasConsidering
  global brasIndent brasLastError

  #parray brasCmd
  #parray brasTinfo
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
    #if $brasOpts(-d) {
    #  bras.dmsg $brasIndent "have seen `$target' in `[pwd]' already"
    #}
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


  ## handle targets without predicate
  if { ![info exist brasTinfo($target,[pwd],pred)] } {
    bras.lastMinuteRule $target $brasIndent

    ## Check if there is still no predicate available
    if {![info exist brasTinfo($target,[pwd],pred)] } {
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
	      "don't know how to make, no rule and file does not exist"
	}
	append brasLastError \
	    "\ndon't know how to make `$target' in `[pwd]'"
	set brasTinfo($target,[pwd],done) -1
	set res -1
      }
      unset brasConsidering($target,[pwd])
      cd $keepPWD
      return $res
    }
  }

  ## Call all predicates for the target in turn
  set res 0
  append brasIndent "  "
  foreach P $brasTinfo($target,[pwd],pred) {
    set pred [lindex $P 0]
    set deps [lrange $P 1 end]
    set newer {}
    set brasCmdlist {}
    set reason ""
    #puts ">>$P<<, >>$deps<<"
    set r [Check.$pred $target $deps newer reason]	;###<<<- HERE
    if {$r==-1} {
      set res -1
    } elseif {$r==1} {
      set res 1
      set brasLastError ""
      break
    }
  }
  set brasIndent [string range $brasIndent 2 end]

  ## If target is ok, return (almost) immediately
  if {$res==0} {
    if { $brasOpts(-d) } {
      bras.dmsg $brasIndent "`$target' in `[pwd]' is up-to-date"
    }
    set brasTinfo($target,[pwd],done) $res

    ## cleanup and return
    unset brasConsidering($target,[pwd])
    cd $keepPWD
    return $res
  }

  ## If target cannot be made, return (almost) immediately
  if {$res==-1} {
    ## This target cannot be made
    if { $brasOpts(-d) } {
      set msg "should make `$target' in `[pwd]', but can't"
      append msg " because\n    one or more dependencies cannot be made"
      bras.dmsg $brasIndent $msg
    }
    set brasTinfo($target,[pwd],done) $res

    ## cleanup and return
    unset brasConsidering($target,[pwd])
    cd $keepPWD
    return $res
  }

  #####
  ##### Target needs to be made
  #####
  
  ## Get the command for the target. If none exists, try to make one up
  set pureDeps [bras.pureDeps $deps]
  if {![info exist brasTinfo($target,[pwd],cmd)]} {
    set _reason {}
    set cmd [bras.defaultCmd $target $pureDeps _reason]
    append reason $_reason
    set preqs {}
    set cmdTargets $target
  } else {
    set ci $brasTinfo($target,[pwd],cmd)
    set cmd $brasCmd($ci,cmd)
    set preqs $brasCmd($ci,preq)
    set cmdTargets $brasCmd($ci,targ)
    unset ci
  }
  
  ## Make sure, all relevant prerequisites have been considered and
  ## are ok or can be made.
  append brasIndent "  "
  foreach preq "$preqs $deps" {
    set r [bras.Consider $preq]
    if {$r==-1} {
      ## move out of here
      set brasIndent [string range $brasIndent 2 end]
      if {$brasOpts(-d)} {
	set msg "should make `$target' in `[pwd]', but can't"
	append msg " because\n    prerequisite $preq cannot be made"
	bras.dmsg $brasIndent $msg
      }
      set brasTinfo($target,[pwd],done) -1

      ## cleanup and return
      unset brasConsidering($target,[pwd])
      cd $keepPWD
      return -1
    }
  }
  set brasIndent "[string range $brasIndent 2 end]"

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
  if { ""=="$cmd" } {
    ## try to find a suitable suffix command
    set _reason {}
    set cmd [bras.defaultCmd $target $pureDeps _reason]
    append reason $_reason
  }
  if {[llength $cmd]} {
    lappend cmdlist "@cd [pwd]"
    lappend cmdlist "@set target \"$cmdTargets\""
    lappend cmdlist "@set newer \"$newer\""
    lappend cmdlist "@set trigger \"$newer\""
    lappend cmdlist "@set deps \"$pureDeps\""
    lappend cmdlist $cmd 
  }
  #puts $cmdlist

  ## Mark all targets of the command as done
  set also {}
  foreach t $cmdTargets {
    set brasTinfo($t,[pwd],done) 1
    if {"$t"!="$target"} {
      lappend also $t
    }
  }

  if { $brasOpts(-d) } {
    regsub -all "\n" $reason "\n    " reason
    bras.dmsg $brasIndent \
	"making `$target' in `[pwd]' because$reason"
    if {"$cmd"==""} {
      bras.dmsg $brasIndent \
	  "    warning: nothing to execute"
    }
    if {"$also"!=""} {
      bras.dmsg $brasIndent \
	  "same command makes: $also"
    }
  }


  ## finish up and return
  unset brasConsidering($target,[pwd])
  cd $keepPWD
  return 1
}

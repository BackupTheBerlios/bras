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
# $Revision: 1.9 $, $Date: 1999/02/02 06:41:59 $
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
## Consider prerequisites of given rule
## RETURN:
##  -1, if one of them cannot be made
##   1 if all can be made or are ok already
##
proc bras.ConsiderPreqs {rid} {
  global brasIndent brasRule brasOpts

  ## If this was already checked before, return immediately
  if {$brasRule($rid,run)!=0} {
    return $brasRule($rid,run)
  }

  set t $brasRule($rid,targ)
  if {$brasOpts(-d)} {
    bras.dmsg $brasIndent "considering prerequisites for `$t'"
  }

  append brasIndent "  "
  set preqNew {}
  foreach preq $brasRule($rid,preq) {
    #shit ## BrasSearchPath is no good for prerequisites, therefore
    #shit ## bras.ConsiderKernel instead of bras.Consider is used.
    set r [bras.Consider preq]
    lappend preqNew $preq
    if {$r==-1} {
      ## move out of here
      set brasIndent [string range $brasIndent 2 end]
      return -1
    }
  }
  set brasRule($rid,preq) $preqNew
  set brasIndent "[string range $brasIndent 2 end]"
  return 1
}
########################################################################
#
# This proc is supposed to be overridden by the user if necessary. For
# a given target it must return a list of targets. The list of targets
# is considered in turn until one is found which is up-to-date or can
# be made.
#

# This default implementation returns the input unchanged if the
# global variable BrasSearchPath is not set or if target starts with
# @ or is not a relative pathname. Otherwise, all elements of
# BrastSearchPath are prepended to target and the resulting list is
# returned. 
proc BrasExpandTarget {target} {
  global BrasSearchPath
  #puts "BrasExpandTarget $target"
  if {![info exist BrasSearchPath]} { 
    return [list $target]
  }

  ## Don't expand @-names
  if {[string match @* $target]} {
    return [list $target]
  }

  ## Don't expand names which contain a path
  if {"[file tail $target]"!="$target"} {
    return [list $target]
  }

#   set ptype [file pathtype $target]
#   if {"$ptype"!="relative"} {
#     return [list $target]
#   }

  set res {}
  foreach x $BrasSearchPath {
    if {"$x"!="."} {
      lappend res [file join $x $target]
    } else {
      lappend res $target
    }
  }
  #puts "BrasExpandTarget returns $res"
  return $res
}
########################################################################
#
# Check whether the target needs to be rebuilt.
#
# This is merely a wrapper around bras.ConsiderKernel which applies
# BrasSearchPath.
#
## RETURN
## 0: no need to make target
## 1: target will be made
## -1: target needs to be made, but don't know how
##
## The parameter target might be changed according to succes in
## searching BrasSearchPath.
##
proc bras.Consider {_target} {
  upvar $_target target
  global brasIndent brasOpts

  set candidates [BrasExpandTarget $target]
  if {$brasOpts(-d) &&
      ([llength $candidates] || "$target"!="[lindex $candidates 0]")} {
    bras.dmsg $brasIndent "expansion of `$target' is `$candidates'"
  }

  ## We first take a look to see if one of the candidates is an
  ## existing file 
  foreach c $candidates {
    if {[file exist $c]} {
      set target $c
      return [bras.ConsiderKernel $c]
    }
  }

  ## Not an existing file, so disregard the search path (according to
  ## Paul Duffin).
  return [bras.ConsiderKernel $target]

  
#   foreach c $candidates {
#     set res [bras.ConsiderKernel $c]
#     #bras.dmsg $brasIndent "got $res"
#     if {$res>=0} {
#       set target $c		;# return changed target
#       return $res
#     }
#   }
#   return -1
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
## o Run the target's rule mentioned in brasTinfo($t,$d,rule)
## Three cases are possible:
##   1) The rule returns -1, i.e. the target should be made, but
##      some of its dependencies are not available or cannot be
##      made. In this case, -1 is returned.
##   2) The rule returns 0, i.e. the target is up-to-date.
##      Then 0 is returned.
##   3) The rule returns 1, i.e. the target must be made. Then the
##      steps described below are executed.
## o All prerequisites of the rule are all considered. Two cases are
##   then possible: 
##   1) One of them must be made, but cannot, i.e. we receive
##      -1. Then -1 is immediately returned.
##   2) All of them are ok or can be made. Then the command is
##      added to the list of commands to be executed and all targets
##      stored for the command are marked in their done-field with 1. 
##      Finally 1 is returned.
##
##
proc bras.ConsiderKernel {target} {
  global brasRule brasTinfo argv0 brasOpts brasConsidering
  global brasIndent brasLastError

  #parray brasCmd
  # parray brasTinfo
  ## change dir, if target starts with `@'
  if {[string match @* $target]} {
    set keepPWD [bras.followTarget $target]
    set target [file tail $target]
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

  ##
  ## Call the target's rule
  ##
  append brasIndent "  "
  set rid $brasTinfo($target,[pwd],rule) 
  set rule $brasRule($rid,type)
  set deps $brasRule($rid,deps)
  set newer {}
  set brasCmdlist {}
  set reason ""
  #puts ">>$P<<, >>$deps<<"
  set res [Check.$rule $target deps newer reason]	;###<<<- HERE

  if {$res==1} {
    ## target must be made, but we have to check, if all prerequisites
    ## are ok.
    set res [bras.ConsiderPreqs $rid]
    if {$res==1} {
      set brasLastError ""
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
      bras.dmsg $brasIndent $msg
    }
    set brasTinfo($target,[pwd],done) $res

    ## cleanup and return
    unset brasConsidering($target,[pwd])
    cd $keepPWD
    return $res
  }

  #####
  ##### Target must be made
  #####

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
  
  ## If this command was already executed, not much more has to be done
  if {1==$brasRule($rid,run)} {
    append reason "\nbut command was already executed previously"
    set cmd { }
  } else {
    ## Get the command for the target. If none exists, try to make one
    ## up.
    set pureDeps [bras.pureDeps $deps]
    if {""=="$brasRule($rid,cmd)"} {
      set _reason {}
      set patrigs {}
      set cmd [bras.defaultCmd \
		   $brasRule($rid,type) $target $pureDeps _reason patrigs]
      append reason $_reason
    } else {
      set cmd $brasRule($rid,cmd)
      set brasRule($rid,run) 1
    }

    ## Add the command for this target to the list of commands. We go
    ## right through cmdlist here, which is somewhere up the stack,
    ## since it does not make sense to set the local brasCmdlist first.
    if {[llength $cmd]} {
      lappend cmdlist "@cd [pwd]"
      lappend cmdlist "@set target \"$target\""
      lappend cmdlist "@set targets \"$brasRule($rid,targ)\""
      #lappend cmdlist "@set newer \"$newer\""
      if {[info exist patrigs] && "$patrigs"!=""} {
	lappend cmdlist "@set patternTriggers \"$patrigs\""
      }
      lappend cmdlist "@set trigger \"$newer\""
      lappend cmdlist "@set deps \"$pureDeps\""
      lappend cmdlist "@set preq \"$brasRule($rid,preq)\""
      lappend cmdlist $cmd 
    }
    #puts $cmdlist
  }

  if { $brasOpts(-d) } {
    regsub -all "\n" $reason "\n    " reason
    bras.dmsg $brasIndent \
	"making `$target' in `[pwd]' because$reason"
    if {"$cmd"==""} {
      bras.dmsg $brasIndent \
	  "    warning: nothing to execute"
    }
    ## Filter this target from target list of the rule
    set also ""
    foreach t $brasRule($rid,targ) {
      if {"$target"!="$t"} {
	lappend also $t
      }
    }
    if {"$also"!=""} {
      bras.dmsg $brasIndent \
	  "same command makes: $also"
    }
  }

  ## finish up and return
  set brasTinfo($target,[pwd],done) 1
  unset brasConsidering($target,[pwd])
  cd $keepPWD
  return 1
}

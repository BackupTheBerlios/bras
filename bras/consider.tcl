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
# $Revision: 1.13 $, $Date: 1999/07/24 11:18:22 $
########################################################################

########################################################################
##
## bras.dmsg
##
proc bras.dmsg {dind msg} {
  regsub -all "\n" $msg "\n\#$dind" msg
  puts "\#$dind$msg"
}
########################################################################
proc ::bras::findIndirectDeps {target dep} {
  variable Ideps

  ## The expansion is not performed for @-deps since it is not at
  ## all clear whether the resulting deps should get the @-prefix or
  ## not. 
  if {[string match @* $dep]} {
    return $dep
  }

  foreach rexp $Ideps(list) {
    if {![regexp $rexp $dep]} continue

    if {[catch {$Ideps($rexp) $target $dep} msg]} {
      global errorInfo
      puts stderr $errorInfo
      exit 1
    } else {
      return $msg
    }
  }
  return $dep
}
########################################################################
#
# If a non-empty string is returned, it is an expanded dependency
# about which something is know, i.e. it either already exists as a
# file or there is an explicit rule describing how to make it. 
#
proc BrasSearchDependency {dep} {
  global brasSearchPath brasSearched brasTinfo

  ## Don't search for targets which are the result of a search already.
  if {[info exist brasSearched([pwd],$dep)]} {
    return $dep
  }

  ## Don't expand @-names
  if {[string match @* $dep]} {
    return $dep
  }

  ## Don't expand non-relative paths
  set ptype [file pathtype $dep]
  if {"$ptype"!="relative"} {
    if {[file exist $dep] || [info exist  brasTinfo($dep,[pwd],rule)]} {
      set brasSearched([pwd],$dep) 1
      return $dep
    } else {
      return {}
    }
  }

  ## If there is no searchpath, assume .
  if {[info exist brasSearchPath([pwd])]} { 
    set path $brasSearchPath([pwd])
  } else {
    set path [list {}]
  }

  ## Try to find the dep as a file along the searchpath
  foreach x $path {
    if {"$x"=="."} {set x {}}
    set t [file join $x $dep]
    if {[file exist $t]} {
      set brasSearched([pwd],$t) 1
      return $t
    }
  }

  ## Try to find an explicit rule for the dependency along the
  ## searchpath 
  foreach x $path {
    if {"$x"=="."} {set x {}}
    set t [file join $x $dep]
    ## Now it may be an @-target
    if {[string match @* $t]} {
      set keepPWD [bras.followTarget $t]
      set tail [file tail $t]
      set found [info exist brasTinfo($tail,[pwd],rule)]
      cd $keepPWD
    } else {
      set found [info exist brasTinfo($t,[pwd],rule)]
    }
    if {$found} {
      set brasSearched([pwd],$t) 1
      return $t
    }
  }

  #puts "BrasExpandTarget returns $res"
  return {}
}
########################################################################
proc bras.leaveDir {newDir} {
  global brasOpts

  if {"$newDir"=="."} return

  if {!$brasOpts(-s)} {
    puts "cd $newDir"
  }
  cd $newDir
}
########################################################################
proc ::bras::listConsider {targets} {
  set depInfo {}
  foreach target $targets {
    set res [bras.Consider $target]
    if {$res<0} {
      return -code error "$target cannot be made"
    }
    if {[string match @* $target]} {
      lappend depInfo [string range $target 1 end] $res
    } else {
      lappend depInfo $target $res
    }
  }

  return $depInfo
}
########################################################################
##
## This terminates bras.Consider after cleaning up a bit.
##
proc bras.returnFromConsider {target keepPWD res} {
  global brasTinfo brasConsidering

  set brasTinfo($target,[pwd],done) $res
  unset brasConsidering($target,[pwd])
  bras.leaveDir $keepPWD
  return -code return $res
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
proc bras.Consider {target} {
  global brasRule brasTinfo argv0 brasOpts brasConsidering
  global brasIndent brasLastError

  ## change dir, if target starts with `@'. Save current dir in
  ## keepPWD.
  set keepPWD .
  if {[string match @* $target]} {
    set keepPWD [bras.followTarget $target]
    set target [file tail $target]
    if {"$keepPWD"=="[pwd]"} {
      set keepPWD .
    }
  }

  if {!$brasOpts(-s) && "$keepPWD"!="."} {
    puts "cd [pwd]"
  }


  ## check, if this target was handled already along another line of
  ## reasoning 
  if [info exist brasTinfo($target,[pwd],done)] {
    if {$brasOpts(-d)} {
      bras.dmsg $brasIndent "have seen `$target' in `[pwd]' already"
    }
    set pwd [pwd]
    bras.leaveDir $keepPWD
    return $brasTinfo($target,$pwd,done)
  }

  ## check for dependeny loops
  if {[info exist brasConsidering($target,[pwd])]} {
    puts stderr \
	"$argv0: dependency loop detected for `$target' in `[pwd]'"
    exit 1
  }

  ## Mark the target as being under consideration to prevent
  ## dependency loops.
  set brasConsidering($target,[pwd]) 1


  ## describe line of reasoning
  if $brasOpts(-d) {
    bras.dmsg $brasIndent "considering `$target' in `[pwd]'"
  }

  ## Prepare for further messages
  append brasIndent "  "

  ## handle targets without rule
  if { ![info exist brasTinfo($target,[pwd],rule)] } {
    bras.lastMinuteRule $target $brasIndent

    ## Check if there is still no rule available
    if {![info exist brasTinfo($target,[pwd],rule)] } {
      set brasIndent [string range $brasIndent 2 end]
      if {[file exist $target]} {
	## The target exists as a file, this is ok.
	if $brasOpts(-d) {
	  bras.dmsg $brasIndent \
	      "`$target' is ok, file exists and has no rule"
	}
	bras.returnFromConsider $target $keepPWD 0
      } else {
	## The file does not exist, so we decide it must be remade, but
	## we don't know how.
	if $brasOpts(-d) {
	  bras.dmsg $brasIndent \
	      "don't know how to make, no rule and file does not exist"
	}
	append brasLastError \
	    "\ndon't know how to make `$target' in `[pwd]'"
	
	bras.returnFromConsider $target $keepPWD -1
      }
    }
  } else {
    ## Try to find a command, if there is none. Again, lastMinuteRule
    ## is called. This might even add a depenency to the front of the
    ## dependency list, which is quite right if the command found uses
    ## [lindex $deps 0].
    set rid $brasTinfo($target,[pwd],rule)
    if {![string length $brasRule($rid,cmd)]} {
      bras.lastMinuteRule $target $brasIndent
    }
  }

  ##
  ## Find the target's rule and prepare depenencies by first expanding
  ## them along the search path and then by invoking the indirect-list.
  ##
  set rid $brasTinfo($target,[pwd],rule) 
  set deps $brasRule($rid,deps)
  set allDeps {}
  foreach d $deps {
    if {"[set t [BrasSearchDependency $d]]"!=""} {
      set d $t
    }
    set allDeps \
	[concat $allDeps [::bras::findIndirectDeps $target $d]]
  }

  if {$brasOpts(-d)} {
    bras.dmsg $brasIndent \
	"full dependency list of `$target' is: `$allDeps'"
  }

  ##
  ## Call the target's rule. [catch] is used because it is assumed
  ## that a rule calls ::bras::listConsider for the dependency list,
  ## which may return an error. 
  ##
  set rule $brasRule($rid,type)
  if {[catch [list Check.$rule $rid $target reason $allDeps] res]} {
    set brasIndent [string range $brasIndent 2 end]
    bras.returnFromConsider $target $keepPWD -1
  }

  set brasIndent [string range $brasIndent 2 end]

  ## If target was up-to-date already, return (almost) immediately
  if {$res==0} {
    if { $brasOpts(-d) } {
      bras.dmsg $brasIndent "`$target' in `[pwd]' is up-to-date"
    }
    bras.returnFromConsider $target $keepPWD 0
  }

  ## If target cannot be made, return (almost) immediately
  if {$res==-1} {
    ## This target cannot be made
    if { $brasOpts(-d) } {
      set msg "should make `$target' in `[pwd]', but can't"
      bras.dmsg $brasIndent $msg
    }
    bras.returnFromConsider $target $keepPWD -1
  }

  ## Target was made
  if { $brasOpts(-d) } {
    regsub -all "\n" $reason "\n    " reason
    bras.dmsg $brasIndent \
	"made `$target' in `[pwd]' because$reason"
  }

  ## All other targets of this rule are assumed to be made now. Mark
  ## them accordingly and filter them out for a message
  set also ""
  foreach t $brasRule($rid,targ) {
    if {"$target"!="$t"} {
      lappend also $t
      set brasTinfo($t,[pwd],done) 1
    }
  }
  if {"$also"!="" && $brasOpts(-d)} {
    bras.dmsg $brasIndent \
	"same command makes: $also"
  }

  ## finish up and return
  bras.returnFromConsider $target $keepPWD 1
}

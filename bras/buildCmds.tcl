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
## bras.evalExist -- 
##  Check if target exits. If not, build commands to generate it
##
if 0 {
proc bras.evalExist {target dind} {
  global brasRules brasOpts brasSrule
  set res {}

  #puts ">>evalExist $target"

  if { [file exist $target] } {
    return $res
  }
  if $brasOpts(-d) {
    bras.dmsg $dind "building `$target' in `[pwd]' because does not exist"
  }
  set cmd $brasRules($target,[pwd],cmd)

  if { "$cmd"=="" } {
    set suffix [file extension $target]
    if [info exist brasSrule($suffix)] {
      set cmd $brasSrule($suffix)
    }
  }
  if { [llength $cmd] } {
    lappend res "@cd [pwd]"
    lappend res "@set target $target"
    lappend res $cmd
  }
  return $res
}
}
########################################################################
##
## Check whether pattern rule no. $i is a candidate for further
## consideration, i.e. matches $target.
##
proc bras.isCandidate {target i} {
  global brasPrule
  return [regexp "^$brasPrule($i,target)\$" $target]
}
########################################################################
##
## Try to find a pattern rule that matches target and one of deps in
## order to use its command as a default command.
##
## _reason gets appended information, if brasOpts(-d) is set
##
proc bras.defaultCmd {target deps _reason} {
  upvar $_reason reason
  global brasPrule brasOpts

  ## need to check all pattern rules
  set nextID $brasPrule(nextID)
  for {set i 0} {$i<$nextID} {incr i} {
    ## This one might have been deleted.
    if { ![info exist brasPrule($i,target)] } continue

    ## Is this one a candidate?
    if { ![bras.isCandidate $target $i] } continue

    ## Generate the derived depencencies
    foreach d $brasPrule($i,dep) {
      lappend l [Dep$d $target]
    }
    
    ## Cross check list l with list deps
    foreach d $deps {
      foreach x $l {
	if { "$x"!="$d" } continue

	## ok, return the command
	if $brasOpts(-d) {
	  append reason \
	      "\nusing command from pattern rule "
	  append reason "$brasPrule($i,dep)->$brasPrule($i,target)"
	}
	return $brasPrule($i,cmd)
      }
    }
  }
}    

########################################################################
##
## bras.evalRule --
## Check whether any dependencies are newer or do not exist. If so,
## return command list to generate the dependencies and the target.
##
## PARAMETERS:
##   target -- name of the target
##   dind -- indent for -d messages
##
## RETURN
## o If `target' needs some work, a list of commands recursively
##   including those to generate the dependencies is returned.
## o If `target' is ok, the emtpy string is returned.
##
proc bras.evalRule {target dind} {
  global brasRules brasSrule brasOpts

  #puts ">>newer: $target<<"
  set reason "building `$target' in `[pwd]' because:"

  ##
  ## Check, if there is an obvious reason to build the target,
  ## i.e. whether it has an Always-rule or does not exist.
  ##
  set targetExist 0
  set always 0
  if { "$brasRules($target,[pwd])"=="Always" } {
    ## For an Always-rule, the reason is obvious
    append reason "\n    must always build"
    set always 1

  } elseif {[file exists $target]} {
    ## don't mess with this rule any further if it is an Exist-Rule
    if { "$brasRules($target,[pwd])"=="Exist" } {
      return {}
    }
    set targetExist 1
    file stat $target stat
    set ttime $stat(mtime)
    
  } else {
    if $brasOpts(-d) {
      append reason "\n    does not exist"
    }
  }

  ##
  ## Handle dependencies
  ##
  set res {}
  set deps {}
  set newer {}
  foreach dep $brasRules($target,[pwd],deps) {
    ## check whether the dependency needs some work
    set cmd [bras.buildCmds $dep "$dind  "]
    if [string match @* $dep] {
      set dep [string range $dep 1 end]
    }
    lappend deps $dep
    if { ""!="$cmd"} {
      if { "*"=="$cmd" } {
	## dependency was handled before and had commands
	if $brasOpts(-d) {
	  append reason \
	      "\n    dependency `$dep' rebuilt (for other target)"
	}
      } else {
	set res [concat $res $cmd]
	if $brasOpts(-d) {
	  append reason "\n    dependency `$dep' rebuilt"
	}
      }
      lappend newer $dep
      continue
    }

    ## if the dependency is ok, it might already be newer and should
    ## probably be added to variable `newer'
    if !$targetExist {
      lappend newer $dep
      continue
    }
    file stat $dep stat
    if { $ttime<$stat(mtime) } {
      lappend newer $dep
      if $brasOpts(-d) {
	append reason "\n    older than `$dep'"
      }
    }
  }
  
  if { $targetExist && ![llength $newer] && !$always} {return {}}

  set cmd $brasRules($target,[pwd],cmd)
  #puts "cmd for `$target' is `$cmd'"


  if { ""=="$cmd" } {
    ## try to find a suitable suffix command
    set cmd [bras.defaultCmd $target $deps reason]
  }
  
  if $brasOpts(-d) {
    bras.dmsg $dind $reason
  }

  if { [llength $cmd] } {
    lappend res "@cd [pwd]"
    lappend res "@set target $target"
    lappend res "@set newer \"$newer\""
    lappend res "@set deps \"$deps\""
    lappend res $cmd
  } elseif { "$res"=="" } {
    set res { }
  }
    
  #puts "newer returns `$res'"
  return $res
}
########################################################################
##
## bras.lastMinuteRule
##   tries to create a rule from braPrule for targets that don't
##   have any explicit rule.
##
proc bras.lastMinuteRule {target dind} {
  global brasPrule brasOpts brasRules
  set nextID $brasPrule(nextID)

  ## try all pattern rules
  for {set i 0} {$i<$nextID} {incr i} {
    ## This one might have been deleted.
    if { ![info exist brasPrule($i,target)] } continue

    ## Is this one a candidate?
    if { ![bras.isCandidate $target $i] } continue

    ## Check if a derived dependency exists as file
    foreach d $brasPrule($i,dep) {
      set depfile [Dep$d $target]
      if { [file exists $depfile] } {
	break
      }
      unset depfile 
    }
    if { ![info exist depfile] } continue
    
    ## Ok, enter the new rule
    $brasPrule($i,type) $target $depfile $brasPrule($i,cmd)
    if $brasOpts(-d) {
      set msg "creating $brasPrule($i,type)-rule from pattern "
      append msg "($brasPrule($i,dep) -> $brasPrule($i,target))"
      bras.dmsg $dind $msg
    }
    #parray brasRules
    return
  }
}   
########################################################################
##
## PARAMETERS:
##   target -- target to be build
##   dind -- indent for -d messages
##
## RETURN
## o If `target' needs some work, a list of commands recursively
##   including those to generate the dependencies is returned.
## o If `target' is ok, the emtpy string is returned.
## o If `target' was handled already along another line of reasoning
##   and if it has been decided to rebuild it, "*" is returned.
##
proc bras.buildCmds {target dind} {
  global brasRules brasSrule argv0 brasOpts brasConsidering

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
      bras.dmsg $dind \
	  "have seen `$target' in `[pwd]' already"
    }
    if {$brasRules($target,[pwd],done)} {
      cd $keepPWD
      return "*"
    } else {
      cd $keepPWD
      return {}
    }
  }

  ## check for dependeny loops
  if {[info exist brasConsidering($target,[pwd])]} {
    puts stderr \
	"$argv0: dependency loop detected for target `$target'"
    exit 1
  }
  set brasConsidering($target,[pwd]) 1

  if $brasOpts(-d) {
    bras.dmsg $dind "considering `$target' in `[pwd]'"
  }

  ## handle targets without rule
  if {![info exist brasRules($target,[pwd])] } {
    ## try to create rule on the fly from suffix
    bras.lastMinuteRule $target $dind
  }

  if {![info exist brasRules($target,[pwd])] } {
    ## no rule available
    if [file exist $target] {
      if $brasOpts(-d) {
	bras.dmsg $dind \
	    "`$target' is ok, file exists and has no rule"
      }
      set brasRules($target,[pwd],done) 0
      unset brasConsidering($target,[pwd])
      cd $keepPWD
      return {}
    } else {
      puts stderr "$argv0: no rule to make target `$target' in `[pwd]'"
      exit 1
    }
  }

  set res [bras.evalRule $target $dind]
  if { $brasOpts(-d) && "$res"=="" } {
    bras.dmsg $dind "`$target' in `[pwd]' is up-to-date"
  }

  if { "$res"=="" } {
    set brasRules($target,[pwd],done) 0
  } else {
    set brasRules($target,[pwd],done) 1
  }

  #parray brasConsidering
  unset brasConsidering($target,[pwd])
  cd $keepPWD
  return $res
}
########################################################################

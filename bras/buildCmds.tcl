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
  if { "$brasRules($target,[pwd])"=="a" } {
    ## For an Always-rule, the reason is obvious
    append reason "\n    must always build"
    set always 1

  } elseif {[file exists $target]} {
    ## don't mess with this rule any further if it is an Exist-Rule
    if { "$brasRules($target,[pwd])"=="e" } {
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

  if ![llength $cmd] {
    ## try to find a suitable suffix command
    set type $brasRules($target,[pwd])
    set suffix [file extension $target]
    foreach d $deps {
      set ds [file extension $d]
      #puts "checking $suffix $ds"
      if {[info exist brasSrule($suffix,$ds,cmd)]
	  && "$brasSrule($suffix,$ds,type)"=="$type"} {
	set cmd $brasSrule($suffix,$ds,cmd)
	if $brasOpts(-d) {
	  append reason \
	      "\n    using command from suffix-rule `$ds'->`$suffix'"
	}
	#puts "found `$cmd'"
	break
      }
    }
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
##   tries to create a rule from braSrule for targets that don't
##   have any explicit rule.
##
proc bras.lastMinuteRule {target suffix dind} {
  global brasSrule brasOpts brasRules

  #puts "lastMinute `$target' `$suffix'"
  #parray brasSrule
  if ![info exist brasSrule($suffix,deps)] return

  set base [file rootname $target]
  foreach dep $brasSrule($suffix,deps) {
    if ![file exist $base$dep] continue
    if { "n"=="$brasSrule($suffix,$dep,type)" } {
      Newer $target $base$dep $brasSrule($suffix,$dep,cmd)
    } else {
      Exist $target $base$dep $brasSrule($suffix,$dep,cmd)
    }
    if $brasOpts(-d) {
      set msg "creating Newer-rule for `$target'"
      append msg " from rule `$dep'->`$suffix'"
      bras.dmsg $dind $msg
    }
    #parray brasRules $target,*
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
  global brasRules brasSrule argv0 brasOpts

  ## change dir, if target starts with `@'
  if {[string match @* $target]} {
    set t [string range $target 1 end]
    set keepPWD [pwd]
    set dir [file dir $t]
    if [catch "cd $dir" msg] {
      puts stderr \
	  "cannot change from `[pwd]' to `$dir' for target `$target'"
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

  if $brasOpts(-d) {
    bras.dmsg $dind "considering `$target' in `[pwd]'"
  }

  ## handle targets without rule
  if {![info exist brasRules($target,[pwd])] } {
    ## try to create rule on the fly from suffix
    set suffix [file extension $target]
    bras.lastMinuteRule $target $suffix $dind
  }

  if {![info exist brasRules($target,[pwd])] } {
    if [file exist $target] {
      if $brasOpts(-d) {
	bras.dmsg $dind \
	    "`$target' is ok, file exists and has no rule"
      }
      set brasRules($target,[pwd],done) 0
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

  cd $keepPWD
  #puts "xxxxxxxxx $res xxxxxxx"

  return $res
}
########################################################################

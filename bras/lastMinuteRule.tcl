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
## bras.lastMinuteRule
##   tries to create a rule from brasPrule for targets that don't
##   have any explicit rule.
##
## Since we don't have any dependencies available here, only the
## target can select a rule. 
##
## If a rule matches the target, its GenDep-proc is called to generate
## the dependency. If that dependeny exists as a file, or if there is
## a real rule with that dependency as target, the rule is
## used.
##
## If no dependency file is found, all rule matching the target are
## considered again, this time calling lastMinuteRule recursively on
## the generated dependency.
##
## If a rule is (recursively) found, 1 is returned, otherwise 0.
##
## To prevent recursive looping, brasPrule($id,cure) is set to 1 for a
## rule which initiates a recursive search.
##
proc bras.lastMinuteRule {target dind} {
  global brasPrule brasOpts brasRule brasTinfo brasSearched

  set lastID [expr $brasPrule(nextID)-1]
 
  ## If this was called to only generate a command, target has
  ## already a rule and we can only use pattern-rules the type of
  ## which matches the type of the registered rule for $target.
  if {[info exist brasTinfo($target,[pwd],rule)]} {
    set reason "trying to find a command to make `$target'"
    set type $brasRule($brasTinfo($target,[pwd],rule),type)
  } else {
    set reason "trying to make pattern rule for target `$target'"
    set type *
  }

  ## In the first step, we check if there is a rule which matches the
  ## target and generates a dependency which exists as a file
  set ruleID -1
  set activeRules {}
  set activeCandidates {}

  for {set id $lastID} {$id>=0} {incr id -1} {
    ## This rule might have been deleted.
    if { ![info exist brasPrule($id,target)] } continue
    
    ## match the type
    if {![string match $type $brasPrule($id,type)]} continue

    ## match the target
    if {![regexp "^$brasPrule($id,target)\$" $target]} continue

    ## don't check recursively active rules
    if {$brasPrule($id,cure)} {
      append reason \
	  "\n+ `$brasPrule($id,target)' <- `$brasPrule($id,dep)' " \
	  "already active"
      continue
    }

    set which $brasPrule($id,dep)

    ## If the dependency is empty, which may happen for
    ## Exist-rules, this is a way to make this target.
    if {"$which"==""} {
      set ruleID $id
      set dep {}
      append reason " ... success"
      break
    }

    ## generate the dependency with the pattern rule
    set dep [GenDep$which $target]

    append reason \
	"\n+ with `$dep' " \
	"derived from `$brasPrule($id,target)' <- `$brasPrule($id,dep)'"
 
    ## Expand the dependency along the search path
    if {"[set t [BrasSearchDependency $dep]]"!=""} {
      ## good one, use it
      set ruleID $id
      set dep $t
      append reason "\n+ success, `$dep' exists or has explicit rule"
      break
    }

    lappend activeRules $id $dep
  }

  if {$brasOpts(-d) && ""!="$reason"} {bras.dmsg $dind $reason}

  ## If we did not find a rule-id yet, go recursive
  if {$ruleID==-1} {
    if {$brasOpts(-d) && [llength $activeRules]} {
      bras.dmsg $dind "+ no success, going recursive"
    }
    foreach {id dep} $activeRules {
      #set dep [GenDep$brasPrule($id,dep) $target]
      set brasPrule($id,cure) 1
      set ok [bras.lastMinuteRule $dep "$dind  "]
      set brasPrule($id,cure) 0
      if {$ok} {
	set ruleID $id
	break
      }
    }
  }

  if {$ruleID==-1} {
    if {$brasOpts(-d)} {
      bras.dmsg $dind "nothing found"
    }
    return 0
  }

  ## If we arrive here, ruleID>=0 denotes the rule to use.  
  bras.enterRule $brasPrule($id,type) $target $dep $brasPrule($id,cmd)

  if $brasOpts(-d) {
    if {"$type"!="*"} {
      set msg "adding command to $brasPrule($id,type)-rule "
    } else {
      set msg "creating $brasPrule($id,type)-rule "
    }
    append msg "`$target' <- `$dep'"
    bras.dmsg $dind $msg
  }
      
  return 1
}
########################################################################

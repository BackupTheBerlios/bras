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
 
  set reason "trying to make pattern rule for target `$target'"

  ## In the first step, we check if there is a rule which matches the
  ## target and generates a dependency which exists as a file
  set ruleID -1
  set activeRules {}
  set activeCandidates {}

  for {set id $lastID} {$id>=0} {incr id -1} {
    ## This rule might have been deleted.
    if { ![info exist brasPrule($id,target)] } continue
    
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
  $brasPrule($id,type) $target $dep $brasPrule($id,cmd)

  if $brasOpts(-d) {
    #if {""!="$reason"} {bras.dmsg $dind $reason}
    set msg "creating $brasPrule($id,type)-rule "
    append msg "`$target' <- `$dep'"
    bras.dmsg $dind $msg
  }
      
  return 1
}
########################################################################
##
## bras.lastMinuteRule
##   tries to create a rule from brasPrule for targets that don't
##   have any explicit rule.
##
## Since we don't have any dependencies available here, only the
## target can be used to select an appropriate rule. To prevent
## infinite recursion due to pattern-rule chaining, a rule is only
## returned, if the resulting target will not match a pattern-rule
## with a the same or a larger ID.
##
proc bras.lastMinuteRule.BLOODY-OLD {target dind} {
  global brasPrule brasOpts brasRule brasTinfo
  set nextID $brasPrule(nextID)

  ## try all pattern rules in the opposite order in which they were
  ## entered.
  for {set id [expr $nextID-1]} {$id>=0} {incr id -1} {

    if ![bras.isCandidate $target $id] continue

    ## Get the derived dependency and check that it can not trigger a
    ## pattern-rule with an ID greater than or equal to id.
    set depProc GenDep$brasPrule($id,dep) 
    set dep [$depProc $target]
    if {[bras.nextCandidate $dep $id]!=$nextID} {
      #puts "not using $id for $target because $dep"
      continue
    }
    
    ## Ok, enter the new rule
    $brasPrule($id,type) $target $dep $brasPrule($id,cmd)
    if $brasOpts(-d) {
      set msg "creating $brasPrule($id,type)-rule "
      append msg "`$target' <- `$dep' from pattern "
      append msg "($brasPrule($id,target) <- $brasPrule($id,dep))"
      bras.dmsg $dind $msg
    }
    #parray brasRules
    return
  }
}   

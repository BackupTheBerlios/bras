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
## Find the first pattern-rule with an id larger than the
## given one the target of which matches the given target. If none is
## found, $brasPrule(nextID) is returned. 
##
proc bras.nextCandidate.BLOODY-OLD {target id} {
  global brasPrule
  set nextID $brasPrule(nextID)

  for {} {$id<$nextID} {incr id} {
    ## This rule might have been deleted.
    if { ![info exist brasPrule($id,target)] } continue
    
    if [regexp "^$brasPrule($id,target)\$" $target] {
      return $id
    }
  }
  return $id
}
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
 
  if $brasOpts(-d) {
    bras.dmsg $dind "trying to make pattern rule for target `$target'"
  }
  ## In the first step, we check if there is a rule which matches the
  ## target and generates a dependency which exists as a file
  set ruleID -1
  set activeRules {}
  set activeCandidates {}
  for {set id $lastID} {$id>=0} {incr id -1} {
    ## This rule might have been deleted.
    if { ![info exist brasPrule($id,target)] } continue
    
    ## don't check recursively active rules
    if $brasPrule($id,cure) continue

    ## match the target
    if ![regexp "^$brasPrule($id,target)\$" $target] continue

    ## generate the dependency with the pattern rule
    set dep [GenDep$brasPrule($id,dep) $target]

    ## If the dependency list is empty, which may happen for
    ## Exist-rules, this is a way to make this target.
    if {"$dep"==""} {
      set ruleID $id
      break
    }

    ## Expand the dependency into a list of candidates and check if
    ## one of them exists as a file. Note that it is not forbidden for
    ## expanded targets to suddenly have an @-prefix.
    set candidates [BrasExpandTarget $dep]
    if {$brasOpts(-d)} {
      bras.dmsg $dind "  possible dependency `$dep'"
      bras.dmsg $dind "  + searchpath returns `$candidates'"
    }

    set found 0
    foreach c $candidates {
      if {[string match @* $c]} {set c [string range $c 1 end]}
      if {[file exist $c]} {
	set found 1
	break
      }
    }
    if {$found} {
      set ruleID $id
      set dep $c
      set reason "  + file `$c' found"
      break
    }

    ## Try to find an explicit rule for one of the candidates
    foreach c $candidates {
      if {[string match @* $c]} {
	# I am curious if this turns out as a misfeature. 
	set pwd [bras.followTarget $c]
	set found [info exist brasTinfo($c,[pwd],rule)]
	cd $pwd
      } else {
	set found [info exist brasTinfo($c,[pwd],rule)]
      }
      if {$found} break
    }
    if {$found} {
      set ruleID $id
      set dep $c
      set reason "  + explict rule found for `$c'"
      break
    }
    if {$brasOpts(-d)} {
      bras.dmsg $dind \
	  "  + none of them is an existing file nor a rule target"
    }
    lappend activeRules $id
    lappend activeCandidates [lindex $candidates 0]
  }

  ## If we did not find a rule-id yet, go recursive
  if {$ruleID==-1} {
    if {$brasOpts(-d) && [llength $activeCandidates]} {
      bras.dmsg $dind "  + recursively trying `$activeCandidates'"
    }
    foreach id $activeRules dep $activeCandidates {
      #set dep [GenDep$brasPrule($id,dep) $target]
      set brasPrule($id,cure) 1
      set ok [bras.lastMinuteRule $dep "$dind  "]
      set brasPrule($id,cure) 0
      if {$ok} {
	set ruleID $id
	set reason {}
	break
      }
    }
    if {$ruleID==-1} {
      if {$brasOpts(-d)} {
	bras.dmsg $dind "nothing found"
      }
      return 0
    }
  }

  ## If we arrive here, ruleID>=0 denotes the rule to use.  
  $brasPrule($id,type) $target $dep $brasPrule($id,cmd)

  ## There is absolutely no need to pass $dep through searchpath again
  set brasSearched([pwd],$dep) 1

  if $brasOpts(-d) {
    if {""!="$reason"} {bras.dmsg $dind $reason}
    set msg "creating $brasPrule($id,type)-rule "
    append msg "`$target' <- `$dep'"
    bras.dmsg $dind $msg
    set msg "+ using pattern "
    append msg "($brasPrule($id,target) <- $brasPrule($id,dep))"
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

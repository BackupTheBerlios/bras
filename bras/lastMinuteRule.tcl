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
## Check whether pattern rule no. $i is a candidate for further
## consideration, i.e. matches $target.
##
proc bras.isCandidate {target i} {
  global brasPrule
  return [regexp "^$brasPrule($i,target)\$" $target]
}
########################################################################
##
## Find the first pattern-rule with an id larger than the
## given one the target of which matches the given target. If none is
## found, $brasPrule(nextID) is returned. 
##
proc bras.nextCandidate {target id} {
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
## target can be used to select an appropriate rule. To prevent
## infinite recursion due to pattern-rule chaining, a rule is only
## returned, if the resulting target will not match a pattern-rule
## with a the same or a larger ID.
##
proc bras.lastMinuteRule {target dind} {
  global brasPrule brasOpts brasRule brasTinfo
  set nextID $brasPrule(nextID)

  ## try all pattern rules in the opposite order in which they were
  ## entered.
  for {set id [expr $nextID-1]} {$id>=0} {incr id -1} {

    if ![bras.isCandidate $target $id] continue

    ## Get the derived dependency and check that it can not trigger a
    ## pattern-rule with an ID greater than or equal to id.
    set depProc Dep$brasPrule($id,dep) 
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

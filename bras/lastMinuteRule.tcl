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
## bras.lastMinuteRule
##   tries to create a rule from brasPrule for targets that don't
##   have any explicit rule.
##
proc bras.lastMinuteRule {target dind} {
  global brasPrule brasOpts brasRule brasTinfo
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

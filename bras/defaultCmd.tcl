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
## Try to find a pattern rule that matches target and one of deps in
## order to use its command as a default command.
##
## _reason gets appended information, if brasOpts(-d) is set
##
proc bras.defaultCmd {type target deps _reason _patternTrigger} {
  upvar $_reason reason
  upvar $_patternTrigger patternTrigger
  global brasPrule brasOpts

  ## need to check all pattern rules
  set nextID $brasPrule(nextID)
  for {set i [expr $nextID-1]} {$i>=0} {incr i -1} {
    ## This one might have been deleted.
    if { ![info exist brasPrule($i,target)] } continue

    ## If its has the wrong type, it is out of the game
    if {"$type"!="$brasPrule($i,type)"} continue

    ## Is this one a candidate?
    if ![regexp "^$brasPrule($i,target)\$" $target] continue

    ## Check all real dependencies against the pattern rule's MatchDep
    ## function.
    set MatchDep MatchDep$brasPrule($i,dep)

    ## Check to see if any of deps can be matched with MatchDep
    set res [$MatchDep $target $deps]
    if [llength $res] {
      if $brasOpts(-d) {
	append reason \
	    "\nusing command from pattern rule " \
	    "`$type $brasPrule($i,dep)->$brasPrule($i,target)' "\
	    "because `$res' match(es)"
      }
      set patternTrigger $res
      return $brasPrule($i,cmd)
    }
  }
  return {}
}    

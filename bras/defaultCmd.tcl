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
proc bras.defaultCmd {target deps _reason} {
  upvar $_reason reason
  global brasPrule brasOpts

  ## need to check all pattern rules
  set nextID $brasPrule(nextID)
  for {set i [expr $nextID-1]} {$i>=0} {incr i -1} {
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


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
# $Revision: 1.3 $, $Date: 1997/04/30 17:35:28 $
########################################################################


########################################################################
##
## The exist-rule checks if the target exists or not. The target is
## only rebuild, if it does not exist. And only if it does not exist,
## this rule considers the dependencies, since they may be needed to
## create the target.
##
Defrule Exist {target deps _trigger _reason} {
  upvar $_reason reason
  ## _trigger is not used here, but must appear to have the same
  ## interface than other rules.

  if {![file exist $target]} {
    set res 1
    foreach dep $deps {
      set x [bras.Consider $dep]
      if {$x==-1} {
	return -1
      }
    }
    append reason "\ndoes not exist"
    return $res
  } else {
    return 0
  }
}
########################################################################

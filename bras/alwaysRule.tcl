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
# $Revision: 1.4 $, $Date: 1997/05/01 14:52:42 $
########################################################################

########################################################################
##
## It is always decided that the target has to be rebuilt. Since the
## dependencies are necessary to rebuild it, they are all considered. 
##
Defrule Always {target deps _trigger _reason} {
  upvar $_reason reason
  ## _trigger is not used here, but must appear to have the same
  ## interface than other rules.
  
  append reason "\nmust always be made"
  return 1
}
########################################################################

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
# $Revision: 1.3 $, $Date: 1997/05/01 14:52:43 $
########################################################################

########################################################################
##
## This is an extended kind of `proc'. It is used to
## define new types of rules.
##
proc Defrule {Name params body} {
  ## define the pattern rule associated to the rule
  proc Pattern$Name {target deps cmd} "
    bras.PatternRule $Name \$target \$deps \$cmd
  "

  ## define the rule-command itself
  proc $Name {target {deps {}} {cmd {}}} "
    bras.enterRule $Name \$target \$deps \$cmd
  "

  ## There must be exactly 4 parameters for the rule-predicate
  if {[llength $params]!=4} {
    return -code error \
	-errorinfo "a rule must have exactly for parameters"
  }

  ## define the rule-execution
  proc Check.$Name $params $body
}
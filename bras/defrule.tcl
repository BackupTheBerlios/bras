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
# $Revision: 1.6 $, $Date: 1999/07/24 11:18:23 $
########################################################################

########################################################################
##
## This is an extended kind of `proc'. It is used to
## define new types of rules.
##
proc Defrule {Name params body} {
  ## define the rule-command itself
  ## Rules may have 3 or 4 parameters. Those with just 3 are not
  ## interested in dependencies. Nevertheless we add a param to
  ## keep the interface identical. (About to shoot into my foot with
  ## those params?).
  if {[llength $params]==3} {
    set params [concat $params \#]
    proc $Name {target {cmd {}}} "
      bras.enterRule $Name \$target {} \$cmd
    "

    proc Pattern$Name {target cmd} "
      bras.PatternRule $Name \$target {} \$cmd
    "
  } elseif {[llength $params]==4} {
    proc $Name {target {deps {}} {cmd {}}} "
      bras.enterRule $Name \$target \$deps \$cmd
    "

    proc Pattern$Name {target deps cmd} "
      bras.PatternRule $Name \$target \$deps \$cmd
    "
  } else {
    return -code error \
	-errorinfo "a rule must have either three or four parameters"
  }

  ## define the rule-execution
  proc Check.$Name $params $body
}
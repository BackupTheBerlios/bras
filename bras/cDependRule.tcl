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
# $Revision: 1.1 $, $Date: 1997/11/09 19:43:17 $
########################################################################

########################################################################
##
## This file came into being after a discussion with Jason Gunthorpe
## <jgg@gpu.srv.ualberta.ca> about the trickery involved to keep a
## .o-file up-to-date with respect to its .c- or .cc-file. It is so
## tricky because changing the source file or one of its included
## files may change the dependency list itself. Jason wanted to talk
## me into lots of complicated special stuff to implement in into
## bras to be able to handle the problem with Newer-rules --- as you
## do with make. A fresh thought after a good nights sleep revealed
## that the Newer-Rule is simply the wrong type of rule to use.
## Harald Kirsch (1997-11-09)
##
## This rule works as follows:
## If the target exists, it is supposed to contain nothing but file
## names. Those are added to the dependency list and the whole stuff
## is then passed to Newer.
## 
Defrule CDepend {target deps _newer _reason} {
  upvar $_reason reason
  upvar $_newer newer
  
  set reason ""
  set res 0

  if [file exist $target] {
    set in [open $target r]
    set otherDeps [read $in]
    close $in
    concatUnique deps $otherDeps
    append reason "\n(after appending `$otherDeps' to list of deps)"
  }

  set res [Check.Newer $target $deps newer moreReasons]
  append reason $moreReasons

  return $res
}
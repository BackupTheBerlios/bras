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
# $Revision: 1.4 $, $Date: 1999/01/28 22:30:41 $
########################################################################

########################################################################
## For every dependency there are two possible reasons why it is
## newer than the target. Either it is remade or the file is newer
## anyway.
##
## If the target does not exist as a file, every dependency is
## considered newer and is a reason to rebuild the file.
## A problematic case is where the dependency is not remade and does
## not exist. In this case, the target is considered newer than the
## non-existing dependency, i.e. this dependency is no reason to
## remake the target.
##
Defrule Newer {target _deps _newer _reason} {
  upvar $_deps deps
  upvar $_reason reason
  upvar $_newer newer
  
  set reason ""
  set res 0
  
  ## check if target exist, get its mtime
  if {[file exist $target]} {
    file stat $target stat
    set ttime $stat(mtime)
  } else {
    append reason "\ndoes not exist"
    set ttime 0
    set res 1
  }
  
  ## check against every dependency, change dependencies as they are
  ## returned from bras.Consider.
  set newDeps {}
  foreach dep $deps {
    ## Consider the dependency as a target. This may change the
    ## target-name slightly due to application of TargetSearchPath.
    set x [bras.Consider dep]
    lappend newDeps $dep

    if {$x==-1} {return -1}

    ## strip possible @-prefix from dep. It is no longer needed
    if {[string index $dep 0]=="@"} {
      set dep [string range $dep 1 end]
    }

    if {$x} {
      set res 1
      append reason "\ndependency $dep rebuilt"
      lappend newer $dep
      continue
    }

    ## This tests the problematic case mentioned above: dep is
    ## up-to-date but may nevertheless not exist as a file.
    if {![file exist $dep]} continue

    ## The dependency is not remade, but maybe its newer already
    file stat $dep stat
    #puts ">>>$target<-$pdep"
    #puts "$ttime <> $stat(mtime)"
    if {$ttime<$stat(mtime)} {
      set res 1
      append reason "\nolder than `$dep'"
      lappend newer $dep
    }
  }
  set deps $newDeps
  return $res
}

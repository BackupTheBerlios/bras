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
# $Revision: 1.9 $, $Date: 1999/07/24 11:18:24 $
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
Defrule Newer {rid target _reason inDeps} {
  upvar $_reason reason
  global brasOpts

  ## Consider all dependencies in turn
  set depInfo [::bras::listConsider $inDeps]

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
  
  ## check against every dependency. Reasons to make the target are:
  ## a) a dependency was reported to be freshly made
  ## b) a dependency was not made fresh but is neverhteless newer
  set trigger {}
  set deps {}
  foreach {dep x} $depInfo {
    
    lappend deps $dep
    if {$x} {
      set res 1
      append reason "\ndependency $dep rebuilt"
      lappend trigger $dep
      continue
    }

    ## This tests the problematic case mentioned above: dep was
    ## already up-to-date (i.e. $x above is 0) but may nevertheless
    ## not exist as a file. With the current rules this cannot happen,
    ## but someone might have his own strange rules.
    if {![file exist $dep]} {
      append emsg \
 	  "bras(warning): dependency `$dep' "\
	  "of target $target was not made and cannot render the " \
	  "target out of date"
      puts stderr $emsg
      continue
    }

    ## Is the dependency indeed newer now than the target?
    file stat $dep stat
    #puts "$target\($ttime) $dep\($stat(mtime))"
    if {$ttime<$stat(mtime)} {
      set res 1
      append reason "\nolder than `$dep'"
      if {$ttime==0} {append reason " (due to non-existance)"}
      lappend trigger $dep
    }
  }

  if {$res==0} {
    return 0
  }

  return [::bras::invokeCmd $rid $target $deps $trigger]

}

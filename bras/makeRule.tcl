########################################################################
#
# This file is part of bras, a program similar to the (in)famous
# `make'-utitlity, written in Tcl.
#
# Copyright (C) 1996--2000 Harald Kirsch, (kir@iitb.fhg.de)
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
# $Revision: 1.1 $, $Date: 2000/03/05 12:37:28 $
########################################################################
## source version and package provide
source [file join [file dir [info script]] .version]

########################################################################

namespace eval ::bras {
  namespace export Make PatternMake
  namespace export Newer PatternNewer
  namespace export Always PatternAlways
  namespace export Exist PatternExist
}
########################################################################

proc ::bras::Make {targets bexp {cmd {}}} {
  ::bras::enterRule $targets {} $bexp $cmd
}
########################################################################
proc ::bras::PatternMake {trexp gendep bexp cmd} {
  ::bras::enterPatternRule $trexp $gendep $bexp $cmd
}
########################################################################
proc ::bras::checkMake {rid theTarget _reason} {
  variable Rule
  upvar $_reason reason
  #puts "Make: bexp=`$bexp'"

  ## current contents of ::bras::p::{reason,trigger,deps} must be
  ## saved. 
  foreach name {reason trigger deps} {
    set saved($name) [set ::bras::p::$name]
    set ::bras::p::$name {}
  }

  set res 0
  ##
  ## When evaluating bexp, we set the following variables
  ## target -- the target for which this rule was called
  ## targets -- other targets associated with this rule
  ## d -- an automatic dependency generated by a pattern rule
  foreach {targets d b} $Rule($rid,bexp) {
    set target $theTarget;		# set for every boolean
					# expression to avoid
					# interference 
    set r [::bras::p::evaluate $b]
#     if {[catch {expr {[::bras::p::evaluate $b]}} r]} {
#       puts stderr $r
#       puts stderr "    while evaluating expression\n[string trim $b]"
#       exit 1
#     }
    set res [expr {$res || $r}]
  }
  if {$res} {
    set res [::bras::invokeCmd $rid \
		 $theTarget \
		 $::bras::p::deps \
		 $::bras::p::trigger]
  }

  ## restore globals in ::bras::p
  append reason $::bras::p::reason
  foreach name {reason trigger deps} {
    set ::bras::p::$name $saved($name)
  }
  
  return $res
}
########################################################################
#
# Some compatibility rules for rules files which used bras up to and
# including version 0.8.0 .
#
proc ::bras::Newer {targets deps {cmd {}}} {
  Make \
      $targets \
      [concat "\[" older [list $targets] [list $deps] "\]"] \
      $cmd
  #puts "Newer $targets $deps"
}
proc ::bras::PatternNewer {rexp dep cmd} {
  PatternMake $rexp $dep {[older $target $d]} $cmd
}

proc ::bras::Always {targets deps {cmd {}}} {
  Make $targets [concat "\[" true [list $deps] "\]"] $cmd
}

proc ::bras::PatternAlways {rexp dep cmd} {
  PatternMake $rexp $dep {[true $d]} $cmd
}

proc ::bras::Exist {targets {cmd {}}} {
  Make $targets [concat "\[" missing [list $targets] "\]"] $cmd
}


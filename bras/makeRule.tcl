########################################################################
#
# This file is part of bras, a program similar to the (in)famous
# `make'-utitlity, written in Tcl.
#
# Copyright (C) 1996--2000 Harald Kirsch
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
# $Revision: 1.9 $, $Date: 2001/12/30 09:02:10 $
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
  variable nspace
  variable Namespace

  upvar $_reason reason
  #puts "Make: bexp=`$bexp'"

  set currentDir [pwd]
  set dirns $Namespace($currentDir)

  ## Set up a scratch namespace where installPredicate will implement
  ## variables on behalf of the predicates. These variables contain
  ## information which the predicates want to communicate to the
  ## command. If these variables directly entered into the
  ## namespace where the command is run in ($dirns as defined above),
  ## we cannot control in here which are these vars. But we have to
  ## know them in order to clear them before a new condition is tested.
  set keptNspace $nspace
  set nspace ::ns[nextID]
  namespace eval $nspace {}

  ## The condition will itself be run in $dirns. For it to be able to
  ## expand $target, $targets and $d, we have to set them in
  ## $dirns. However, since [consider] can be called recursively, we
  ## have to make sure not to permanently overwrite value set
  ## already. Therefore we keep those values locally.
  foreach n {target targets d} {
    catch {set stack($n) [set [set dirns]::$n]}
  }

  set res 0
  foreach {targets d b} $Rule($rid,bexp) {
    ## transfer values into directory's namespace
    set [set dirns]::target $theTarget
    set [set dirns]::targets $targets
    set [set dirns]::d $d    
    if 0 {
      set cmd [concat uplevel \#0 \
		   [list namespace inscope $Namespace($currentDir) \
			expr [list $b]]]
    } else {
      # does this work without the uplevel stuff?
      set cmd [list namespace eval $dirns [list expr $b]]
    }
    ## $b contains user's code, so care must be taken when
    ## running it.
    if {[catch $cmd r]} {
      cd $currentDir
      trimErrorInfo
      append ::errorInfo \
	  "\n    while checking test `$b' for " \
	  "target `$theTarget'---SNIP---"
      return -code error -errorinfo $::errorInfo
    }
    cd $currentDir
    set res [expr {$res || $r}]
  }

  ## Reset stacked values in $dirns to orignal
  foreach n {target targets d} {
    unset [set dirns]::$n
    catch {set [set dirns]::$n $stack($n)}
  }

  ## If we got some reasons, keep them
  if {[info exist ::[set nspace]::reason]} {
    set reason [set ::[set nspace]::reason]
    unset ::[set nspace]::reason
  } else {
    set reason "\n(condition gives no reason)"
  }

  ## Now run the command.
  if {$res} {
    ## Put variables set by installPredicate in $nspace into $dirns.
    ## Note that 'reason' was purged already above to not contaminate
    ## $dirns now.
    foreach var [info vars [set nspace]::*] {
      set v [namespace tail $var]
      namespace eval $dirns [list upvar \#0 [set nspace]::$v $v]
    }
    set res [::bras::invokeCmd $rid $theTarget $dirns]

    ## Reset variables in $dirns
    foreach var [info vars [set keptNspace]::*] {
      set v [namespace tail $var]
      namespace eval $dirns [list upvar \#0 [set keptNspace]::$v $v]
    }
    
  }
  namespace delete $nspace
  set nspace $keptNspace

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


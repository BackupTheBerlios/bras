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
# $Revision: 1.2 $, $Date: 2000/03/08 22:35:37 $
########################################################################
## source version and package provide
source [file join [file dir [info script]] .version]

########################################################################
#
# Define the predicates to be used as dependencies in Make-rules.
#
# They all go into the namespace ::bras::p
#
########################################################################
namespace eval ::bras::p {
  ## During the evaluation of predicates, those predicates explain
  ## their findings by appending to this variable.
  variable reason {}
  
  ## Predicates may append targets which turn out to trigger them to
  ## true to the following variable.
  variable trigger {}

  ## Predicates may also append targets which they consider to the
  ## following variable.
  variable deps {}
}
########################################################################
#
# runs a given (boolean) expression in a context where only the
# variables t and d are directly accessible.
#
proc ::bras::p::evaluate {bexp} {
  upvar target target
  upvar targets targets
  upvar d d
  if {[catch [concat unset bexp ";" expr $bexp] r]} {
    if {![info exist ::bras::lastError]} {
      global errorInfo
      set ::bras::lastError $errorInfo
    }
    return -code error $r
  }
  return $r
}
########################################################################
#
# Every predicate should run this proc right at the start. It is a
# shortcut declaration of several namespace variables and it expands
# dependencies along searchpath.
#
# PARAMETER
# -- names
# a list of variable names to be installed in namespace
# $::bras::nspace. The name `reason' is always installed and need not
# be mentioned. 
# -- depvars
# a list of variable NAMES (not values) in the calling predicate each
# of which contains dependencies which must be expanded along the
# searchpath.
#
proc ::bras::p::installPredicate { names {depvars {}} } {
  upvar \#0 ::bras::Opts Opts 

  ## Within the calling predicate, we install all variables listed in
  ## $names as local variables linked to variables of the same name in 
  ## the namespace $::bras::nspace. One additional variable called
  ## `reason' is always installed that way.
  foreach n $names {
    uplevel 1 upvar \#0 $::bras::nspace\::$n $n
    uplevel 1 "if {!\[info exist $n\]} {set $n {}}"
  }
  uplevel 1 upvar \#0 $::bras::nspace\::reason reason

  if {$Opts(-d)} {::bras::dmsg "testing `[info level -1]'"}

  ## Expand dependencies stored in any of the varialbles noted in
  ## depvars along the searchpath. The result is put into these
  ## variables again.
  foreach v $depvars {
    upvar $v deps
    set res {}
    foreach d $deps {
      set s [::bras::searchDependency $d]
      if {""=="$s"} {set s $d}
      lappend res $s
    }
    set deps $res
    if {$Opts(-d)} {::bras::dmsg "expanded deps: `$deps'"}
  }
}
########################################################################
#
# tests if any of the targets
# -- does not exist
# -- is older than any of the dependencies listed in $inDeps
# This predicate is also true, if any of the dependencies in $inDeps
# is considered out-of-date.
#
proc ::bras::p::older {targets inDeps} {
  installPredicate {trigger deps} inDeps

  #puts "older:: $targets < $inDeps"

  ## Consider all dependencies in turn
  set results [::bras::consider $inDeps]

  ## cache all mtimes of inDeps
  foreach  d $inDeps   x $results  {
    if {![file exist $d]} {
      ## Ooops. Obviously $d is not really a file but some other
      ## strange stuff. We cannot test its mtime to compare with the
      ## targets but we have $x indicating if $d was just made or
      ## not. If it was made ($x==1) we set the mtime to -1 meaning
      ## that it is very new.
      set mtime($d) [expr {$x?-1:0}]
    } else {
      set mtime($d) [file mtime $d]
    }
  }
  
  set res 0
  foreach t $targets {
    ## check if target exists, get its mtime
    if {[file exist $t]} {
      set ttime [file mtime $t]
    } else {
      set ttime 0
      append reason \
	  "\n`$t' is considered very old because it does not exist"
      set res 1
    }
    ## Now check if $t is older than any of inDeps
    set older {}
    set fresh {}
    foreach d $inDeps {
      if {$mtime($d)<0} {
	## Yes, $d was just made (yet does not exist)
	lappend fresh $d
	::bras::lappendUnique trigger $d
      } elseif {$ttime<$mtime($d)} {
	set res 1
	lappend older $d
	::bras::lappendUnique trigger $d
      }
    }
    if {[llength $fresh]} {
      append reason \
	  "\n`$t' is considered older than just created `$fresh'"
    }
    if {[llength $older]} {
      append reason "\n`$t' is older than `$older'"
    }
  }

  ::bras::concatUnique deps $inDeps

  return $res
}
########################################################################
#
# tests if the given target is not an existing file (or directory)
#
proc ::bras::p::missing {file} {
  installPredicate trigger

  if {![info exist $file]} {
    append reason "\n`$file' does not exist"
    ::bras::lappendUnique trigger $file
    return 1
  }
  return 0
}
########################################################################
#
# always returns 1. The use of [true] is preferred over the use of `1' 
# because of the log-information.
#
proc ::bras::p::true {{inDeps {}}} {
  installPredicate deps inDeps

  ::bras::consider $inDeps

  append reason "\nmust always be made"
  ::bras::concatUnique deps $inDeps
  return 1
}
########################################################################
proc ::bras::p::changed--very-experimental-dont-use {file} {
  installPredicate {trigger deps}
  
  set r [consider $file]

  if {![file exist $file]} {
    append reason "\nmd5-dependency not existing"
    lappend trigger $file
    lappend deps $file
    return 1
  }

  set md5 $file.md5
  set res 0
  if {[catch {exec md5sum --status --check $md5}]} {
    set res 1
    exec md5sum $file >$md5
    append reason "\nchanged md5 of $file"
    lappend trigger $file
    lappend deps $file
  }

  return $res
}
########################################################################
#
# Source the given $file and return a list which contains all
# variables and their values set in $file.
#
proc ::bras::fetchvalues {_ary file} {
  upvar $_ary ary

  ## Want to source in a fresh interpreter
  set ip [interp create]
  
  ## we don't consider predefined variables like tcl_patchLevel.
  foreach x [$ip eval info vars] {
    set predefined($x) 1
  }

  ## source the file
  if {[catch {$ip eval source $file} msg]} {
    return -code error $msg
  }

  ## copy all vars, except thte predefined ones, from $ip into ary
  foreach x [$ip eval info vars] {
    if {[info exist predefined($x)]} continue

    if {[$ip eval array exist $x]} {
      foreach elem [$ip eval array names $x] {
	set ary($x\($elem\)) [$ip eval set $x\($elem\)]
      }
    } else {
      set ary($x) [$ip eval set $x]
    }
  }
  interp delete $ip
}
########################################################################
#
# Tests if any variable set in $pfile changed since last
# called. Comparison is performed with a cache file named $file.vc
#
proc ::bras::p::newvalue {pfile varglob} {
  installPredicate {trigger deps} pfile

  set cache ${pfile}.vc;		# vc -- value cache

  ## if the cache does not exist, immediately return true
  if {![file exist $cache]} {
    ::bras::lappendUnique trigger $pfile
    append reason "\n$cache does not exist"
    file copy $pfile $cache
    return 1
  }
  
  ## get the old and new values from the files
  ::bras::fetchvalues New $pfile
  ::bras::fetchvalues Old $cache

  ## sanity check. Some vars just set should match $varglob
  set vars  [array names New $varglob]
  if {![llength $vars]} {
    set msg {}; append msg \
	"bras(warning): parameter file `$pfile' does not contain " \
	"any variable matching `$varglob'"
    puts stderr $msg
  }
    
  ## Check if any matching variable is either not yet in the cache
  ## file or is not the same as in the parameter file.
  foreach v $vars {
    if {![info exist Old($v)]} {
      append reason "\nnew parameter `$v' found in `$pfile'"
      ::bras::lappendUnique trigger $pfile
      file copy -force $pfile $cache
      return 1
    }
    if {"$Old($v)"!="$New($v)"} {
      append reason "\nparameter `$v' changed from `$Old($v)' to " \
	  "`$New($v)'"
      ::bras::lappendUnique trigger $pfile
      file copy -force $pfile $cache
      return 1
    }
  }
  return 0
}
########################################################################
#
# tests if target $doto is older than any of the files listed in
# dependency cache $dc. As a side-effect, the dependency
# cache is considered and brought up-to-date.
#
proc ::bras::p::dcold {doto dc} {  
  installPredicate {} dc

  ## First of all, the dependency cache $dc must be up-to-date
  ::bras::consider $dc

  ## The rest is trivial
  set in [open $dc r]; set dlist [join [split [read $in]]]; close $in
  return [older $doto $dlist]
}    
########################################################################
#
# tests if a dependency-cache (dc) file is out of date. This is the
# case, if
# -- it does not exist
# -- it is [older] than the given dotc-file
# -- it is [older] than any of the files listed in it
#
proc ::bras::p::oldcache {dc dotc} {
  installPredicate {trigger deps} dotc

  if {![file exist $dc]} {
    append reason "\n`$dc' does not exist"
    ::bras::lappendUnique deps $dotc
    ::bras::lappendUnique trigger $dotc
    return 1
  }

  set in [open $dc r]; set dlist [join [split [read $in]]]; close $in
  set dlist [concat $dotc $dlist]
  return [older $dc $dlist]
}
########################################################################

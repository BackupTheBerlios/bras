########################################################################
#
# This file is part of bras, a program similar to the (in)famous
# `make'-utitlity, written in Tcl.
#
# Copyright (C) 1996, 1997, 1998, 1999
#                    Harald Kirsch, (kir@iitb.fhg.de)
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
# $Revision: 1.3 $, $Date: 1999/06/03 18:01:03 $
########################################################################

##
## This file contains commands intended to be used in brasfiles
## (besides rule-commands which are defined elsewhere).
##

########################################################################
##
## This is useful to set global variables in a way that they can be
## overridden by the environment or on the command line. Typical
## candidates are CC, prefix and the like.
##
## Typical use:
## getenv prefix /usr/local
##
proc getenv {_var {default {}} } {
  upvar $_var var
  global env
  if {[info exist env($_var)]} {
    set var $env($_var)
  } else {
    set var $default
  }
}
########################################################################
##
## Every directory with its own brasfile has its own search path.
## Without arguments, the current path is unchanged.
## The new path is always returned.
##
proc searchpath { {p {never used}} } {
  global brasSearchPath

  if {[llength [info level 0]]==2} {
    ## something was explicitly passed in
    if {[llength $p]} {
      set brasSearchPath([pwd]) $p
    } else {
      unset brasSearchPath([pwd])
      return {}
    }
  } elseif {![info exist brasSearchPath([pwd])]} {
    return {}
  }

  return $brasSearchPath([pwd])
}
########################################################################
##
## include
##   an alias for `source', however we take care to not source any
##   file more than once.
##  
##   If the `name' starts with an `@' it must be a directory. In that
##   case, the $brasFile of that directory is sourced in the same way
##   as if an `@'-target had let to that directory.
##
##   If the `name' does not start with `@', it must be the name of an
##   existing readable file. This one is simpy sourced in.
##
proc include {name} {
  global brasKnown
  
  if [string match @* $name] {
    cd [bras.followTarget [file join $name .]]
    return
  }

  ## To be compatible with followTarget, we first have to move to the
  ## destination directory to get the correct answer from [pwd]. _NO_,
  ## just stripping the directory part from $name is useless, because
  ## it may contain relative parts and parts leading through one or
  ## more soft-links.
  set dir [file dir $name]
  set file [file tail $name]

  set oldpwd [pwd]
  if [catch "cd $dir" msg] {
    set err "bras: include of `$name' tried in directory `$oldpwd'"
    append err " leads to non-existing directory `$dir'"
    puts stderr $err
    exit 1
  }
  set pwd [pwd]
  cd $oldpwd

  if [info exist brasKnown([file join $pwd $file])] return

  bras.gobble $name
}
########################################################################
proc consider {targets} {
  global brasOpts brasIndent

  if {$brasOpts(-d)} {
    set caller [info level -1]
    bras.dmsg $brasIndent "=> on behalf of `$caller':"
    append brasIndent "  "
  }

  set depInfo {}
  foreach target $targets {
    set res [bras.Consider $target]
    if {$res<0} {
      return -code error -errorinfo "$target cannot be made"
    }
    if {[string match @* $target]} {
      lappend depInfo [string range $target 1 end] $res
    } else {
      lappend depInfo $target $res
    }
  }

  if {$brasOpts(-d)} {
    set brasIndent [string range $brasIndent 2 end]
    bras.dmsg $brasIndent "<= done with result $res"
  }

  return $depInfo
}

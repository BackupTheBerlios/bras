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
########################################################################

########################################################################
##
## bras.oneLine
##
proc bras.oneLine {in} {
  set line {}
  while { -1!=[set c [gets $in l]] && [string match {*\\} $l] } {
    append line $l
  }
  append line $l
  regsub -all "\\\\" $line { } line
  if {![llength $line] && $c==-1} {return -1}
  return $line
}
########################################################################
##
## sourceDeps
##   source dependency declarations typically generated by `cc -M'
##   (`cc -xM' on Solaris) and generate dependency lists.
##
##   All parameters except the first are treated as prefixes of
##   dependencies that need not be included in the list. Typical
##   examples would be `/usr' and `/usr/local'.
##
proc sourceDeps {file args} {

  if {![file readable $file]} {
    puts stderr \
	"bras (warning from `sourceDeps'): cannot read [pwd]`$file'"
    return
  }
  set in [open $file]
 
  ## create regexp to filter unwanted dependencies
  if [llength $args] {
    set rex "^[join $args |^]"
    set ex 1
  } else {
    set ex 0
  }
  
  while 1 {
    ## get next line, gobble continuations also
    set line [bras.oneLine $in]
    if { "$line"=="-1" } break
    if ![llength $line] continue

    ## extract target
    regsub {:} $line { } line
    set target [lindex $line 0]
    if {![info exist Deps($target)]} {
      set Deps($target) {}
    }
    ## collect dependencies while filtering unwanted ones
    if $ex {
      foreach d [lrange $line 1 end] {
	if [regexp $rex $d] continue
	lappend Deps($target) $d
      }
    } else {
      foreach d [lrange $line 1 end] {
	lappend Deps($target) $d
      }
    }
  }
  close $in
  foreach x [array names Deps] {
    Newer $x $Deps($x)
  }
}

########################################################################
#
# This file is part of bras, a program similar to the (in)famous
# `make'-utitlity, written in Tcl.
#
# Copyright (C) 1996-2000 Harald Kirsch
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
# $Revision: 1.2 $, $Date: 2000/03/08 22:32:48 $
########################################################################
## source version and package provide
source [file join [file dir [info script]] .version]
#puts "reading [info script]"
##
## This files contains 
## -- the declarations of all namespace-variables
## -- the procs which built up the database,
## -- other misc. procs
##
namespace eval ::bras {

  namespace eval gendep {
    ## This namespace will contain procs which map a target matching a 
    ## pattern rule into a useful dependency. See enterPatternRule for 
    ## more information.
  }

  ##### namespace variables

  ## base
  ##   Directory holding files sourced in by this script, as well as
  ##   files someone might find useful sourcing, in particular those
  ##   with suffix .rules. It is set in .version

  ## Opts
  ##   An array of options controlling bras.
  variable Opts
  set Opts(-d) 0;			# debug output
  set Opts(-k) 0;
  set Opts(-s) 0;			# silent operation
  set Opts(-v) 0;			# verbose operation
  set Opts(-n) 0;			# don't execute any commands
  set Opts(-ve) 0;			# show exec'ed commands

  ## Brasfile
  ##   Name of the rule file used, typically "brasfile" or "Brasfile" 
  variable Brasfile brasfile

  ## Targets
  ##   List of default targets to consider. It is set by the very
  ##   first rule entered into the database

  ## Indent
  ##   Current indent string used by debug messages
  variable Indent ""

  ## Tinfo
  ##   array holding information about targets. With <t> a target,
  ##   <d> its directory, the indices used are:
  ##   <t>,<d>,rule -- index into Rule denoting the rule for <t>,<d>
  ##   <t>,<d>,done -- set, if target was already considered.
  ##                   0: no need to make target
  ##                   1: target will be made
  ##                  -1: target needs to be made, but don't know how

  ## Rule
  ##   database of rules. With integer <i>, the indices are as follows
  ##   <i>,targ -- targets
  ##   <i>,deps -- dependencies
  ##   <i>,cmd  -- command
  ##   all      -- a list of all valid <i>s.
  variable Rule
  set Rule(all) {}

  ## Prule
  ##   database of pattern-rules. Pattern rules are stored and accessed in
  ##   the same order as they are introduced. Therefore each one gets a
  ##   number. The indices are used as follows (<i> denotes an integer):
  ##   all        -- list of all known pattern-rule IDs.
  ##   <i>,trexp  -- regular expression to match target 
  ##   <i>,gendep -- name of dependency generating funciton in
  ##                 ::bras::gendep 
  ##   <i>,cmd    -- command for target/dependency pair
  ##   <i>,cure   -- used by lastMinuteRule, set to 1 if CUrrently
  ##                 REcursively considered.
  variable Prule
  set Prule(all) {}

  ## nextID
  ##   a counter returning unique indices
  variable nextID 0

  ## Known
  ##   array with an element for all files sourced either by following
  ##   an @-target or by an explicit `include'. The directory-part of
  ##   the filename is always normalized by means of [pwd].
  ##

  ## Considering
  ##   is an array with targets as indices. The array element is set
  ##   while ::bras::Consider is working on a target to prevent
  ##   dependency loops

  ## Searchpath
  ## is an array indexed by [pwd] and contains for each directory the
  ## dependency search path. Elements are set by command `searchpath'.

  ## Searched
  ## is an array indexed by [pwd],<name> . If a certain index exists,
  ## <name> is the result of an expansion along brasSearchPath and it
  ## will not be expanded again.

  ## nspace
  ##   internal variable holding the name of the namespace used for
  ##   the next set of predicates and commands. A namespace of this
  ##   name is set up in checkMake, just before the condition of a
  ##   rule is evaluated. All variables a predicate set for the
  ##   command to find later must be set in this namespace.
  variable nspace {}
}

########################################################################
#
# generate a unique number
#
proc ::bras::nextID {} {
  variable nextID
  incr nextID
  return $nextID
}
########################################################################
#
# lappendUnique -- append an element to a list if it is not already in
# there. 
#
proc ::bras::lappendUnique {_list elem} {
  upvar $_list list
  
  if {-1==[lsearch -exact $list $elem]} {
    lappend list $elem
  }
}
########################################################################
#
# concatUnique
#
proc ::bras::concatUnique {_list newElems} {
  upvar $_list list
  
  foreach elem $newElems {
    if {-1!=[lsearch -exact $list $elem]} continue
    lappend list $elem
  }
}
########################################################################
#
# tcl (as of 8.0b1 and previous) does execute a `cd .' thereby
# spoiling its cache for pwd. Since bras happens to execute quite some
# `cd .', calling pwd afterwards, I trick it myself.
#
rename cd _cd
proc cd {dir} {
  if {"$dir"=="."} return
  _cd $dir
}
########################################################################
#
# Depending on command line options, this replaces the normal
# exec-command. 
#
proc ::bras::verboseExec args {
  puts $args
  return [eval ::bras::exec_orig $args]
}
########################################################################
##
## gobble
##   a wrapper around `source $file' to handle errors gracefully
##
proc ::bras::gobble {file} {
  global errorInfo

  if [catch "uplevel #0 source $file" msg] {
    ## strip the last 5 lines off the error stack
    set ei [split $errorInfo \n]
    set l [llength $ei]
    set lastLine [lindex $ei [expr $l-6]]
    regsub {\".*\"} $lastLine "\"[file join [pwd] $file]\"" lastLine
    puts stderr [join [lrange $ei 0 [expr $l-7]] \n]
    puts stderr $lastLine
    exit 1
  }
}
########################################################################
##
## followTarget
##  
## Handle all what is necessary to follow an @-target to its
## home. In particular:
## - change directory
## - read brasfile
## And do all this with the necessary error handling.  
##
## RETURN
##   The current directory (before cd) is returned.
##
proc ::bras::followTarget {target} {
  variable Brasfile
  variable Known
  variable Tinfo
  #puts "followTarget $target"

  set oldpwd [pwd]
  set dir [file dir [string range $target 1 end]]

  ## carefully change directory
  if [catch "cd $dir" msg] {
    set err "bras: dependency `$target' in `"
    append err [file join $oldpwd $brasfile]
    append err "' leads to non-existing directory `$dir'"
    puts stderr $err
    exit 1
  }

  ## check, if we know already the brasfile here
  if {[info exist Known([file join [pwd] $Brasfile])]} {
    return $oldpwd
  }

  ## before really reading the file, mark the current dir as known,
  ## because the file to be read may lead back here again.
  set Known([file join [pwd] $Brasfile]) 1

  ## If the brasfile does not exist, print a warning. There is no need
  ## to terminate immediately, because things might be handled by
  ## default rules.
  if {![file exists ${Brasfile}]} {
    if {0==[llength [array names Tinfo *,[pwd],rule]]} {
      puts stderr \
     "bras warning: no `$Brasfile' found in `[pwd]', so hold your breath"
    }
  } else {
    gobble $Brasfile
  }
  return $oldpwd
}
########################################################################
##
## enterPatternRule
##   Declare a pattern-rule.
##
## PARAMETER
## trexp --
##   regular expression to match a target
## gendep --
##   name of a proc in ::bras::gendep which can map a target which
##   matches trexp into a useful dependency. It must have exactly one
##   paramter which will be the matching target, when it is called.
## bexp --
##   boolean expression to use in a rule derived from this pattern
##   rule 
## cmd --
#    command to attach to a rule derived from this pattern rule
proc ::bras::enterPatternRule {trexp gendep bexp cmd} {
  variable Prule

  ## Emtpy commands are rather useless here
  if {0==[string length $cmd]} {
    return -code error \
	"empty commands are not allowed in pattern rules"
  }

  ## enter the rule
  set id [nextID]
  set Prule(all) [concat $id $Prule(all)]
  set Prule($id,trexp) $trexp
  set Prule($id,gdep)  $gendep
  set Prule($id,bexp)  $bexp
  set Prule($id,cmd)   $cmd
  set Prule($id,cure)  0

  ## create pattern replacement commands for the dependency
  if { 0==[llength [info commands ::bras::gendep::$gendep]] } {
    set body [format {
      set rootname [file rootname $target]
      return [join [list $rootname "%s"] {}]
    } $gendep]
    proc ::bras::gendep::$gendep {target} $body
  }
}
########################################################################
##
## ::bras::enterRule
##    declare a rule
## 
## targets -- list of targets
##    gdep -- a dependency generated in a pattern rule
##    bexp -- a boolean expression 
##     cmd -- a script to generate the target(s)
##
proc ::bras::enterRule {targets gdep bexp {cmd {}} } {
  variable Targets
  variable Rule
  variable Tinfo

  if {[llength $targets]==0} {
    return -code error "The target list may not be empty"
  }

  #puts "enterRule: {$type} {$targets} {$deps} {$cmd} {$bexp}"

  ## if this is the very first explicit rule seen, and if no target was
  ## specified on the command line, this is the default target-list.
  ## It suffices to put just the first element into Targets,
  ## because all of them are made by the command of this rule.
  ## We make it an @-target so that the brasfile may contain `cd here'
  ## and `cd there' without messing things up.
  if {![info exist Targets]} {
    set Targets [file join @[pwd] [lindex $targets 0]]
  }

  ## Although more than one `Make'-command for a target is allowed in
  ## a brasfile, all of those are pooled into one rule
  ## internally. Consequently, if a `Make'-command specifies more than
  ## one target which has already a rule associated, they must all
  ## have that same rule.
  set rid {}
  set tmp {}
  set err 0
  foreach t $targets {
    if {[info exist Tinfo($t,[pwd],rule)]} {
      if {"$rid"==""} {
	set rid $Tinfo($t,[pwd],rule)
      } elseif {$rid!=$Tinfo($t,[pwd],rule)} {
	set err 1
      }
      lappend tmp $t
    }
  }
  if {$err} {
    append msg "The targets `$tmp' all have already a rule, but "\
	"these rules are not all same."
    return -code error -errorinfo $msg
  }

  ## If rid is not set now, initialize a rule 
  if {[llength $rid]==0} {
    set rid [nextID]
    lappend Rule(all) $rid
    set Rule($rid,targ) {}
    set Rule($rid,bexp) {}
    set Rule($rid,cmd) {}
  }

  ## We are sure now, all targets either don't have a rule yet or they 
  ## all have the same.
  foreach t $targets {
    set Tinfo($t,[pwd],rule) $rid
  }

  ## Add the new information into Rule($rid,...)
  concatUnique Rule($rid,targ) $targets
  if {"$cmd"!=""} {
    ## It is no good to have more than one command for a target.
    if {""!="$Rule($rid,cmd)" && "$Rule($rid,cmd)"!="$cmd"} {
      set msg {}; append msg \
	  "bras(warning) in `[pwd]': overriding command " \
	  "`$Rule($rid,cmd)' for target `$targets'" \
	  " with `$cmd'"
      puts stderr $msg
    }
    set Rule($rid,cmd) $cmd

    ## If this rule has a command, we want its boolean expression to
    ## be the first in the list so that it enters its dependencies it
    ## has in front of the dependency list so that [lindex $deps 0] is
    ## equivalent to make's $< .
    set Rule($rid,bexp) \
	[concat [list $targets $gdep $bexp] $Rule($rid,bexp)]
  } else {
    lappend Rule($rid,bexp) $targets $gdep $bexp
  }
  set Rule($rid,run) 0
}
########################################################################
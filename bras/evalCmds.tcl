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
proc bras.unknown args {
  global brasOpts auto_noexec

  #puts "unknown: `$args'"

  set args [eval concat $args]
  #puts "would exec $args"

  ## First let the original `unknown' try to do something useful, but
  ## don't let it execute external commands.
  set auto_noexec 1
  if {![catch "unknown.orig $args" res]} {
    unset auto_noexec
    return $res
  }
  unset auto_noexec

  ## There seems to be a change in the return value of auto_execok
  ## somewhere between 7.4 and 7.6. I try to exploit both versions.
  set name [lindex $args 0]
  set tmp [auto_execok $name]
  if {""=="$tmp" || "0"=="$tmp"} {
    return -code error \
	"command not found when executing `$args'"
  }

#   if {$brasOpts(-N)} {
#     puts stdout $args
#     return {}
#   }
  
#   if {!$brasOpts(-ss)} {
#     ## not super-silent
#     if {!$brasOpts(-s)} {
#       puts stdout $args
#     } else {
#       puts -nonewline stdout .
#     }
#   }
  
  #    return [uplevel exec <@stdin 2>@stderr >@stdout $args]
#   if {!$brasOpts(-v) && !$brasOpts(-s)} {
#     puts $args
#   }

  if {$brasOpts(-ve)} {
    puts $args
    set exec bras.exec
  } else {
    set exec exec
  }
  if {[catch {eval $exec <@stdin 2>@stderr >@stdout $args} msg] } {
    return -code error $msg
  }

}
########################################################################
proc bras.evalCmds {cmds} {
  global brasOpts errorInfo

  rename unknown unknown.orig
  rename bras.unknown unknown

  foreach cmd $cmds {
    if { [string match @cd* $cmd] } {
      set newcwd [string trim [lindex $cmd 1]]
      if { "$newcwd"=="[pwd]" } continue
      set cmd [string range $cmd 1 end]
      if {!$brasOpts(-s)} {
	puts stdout $cmd
      }
      eval $cmd
      continue
    }

    if { "@"==[string index $cmd 0] } {
      set cmd [string range $cmd 1 end]
    }
    if $brasOpts(-v) {
      regsub -all "\n" [string trim $cmd "\n"] "\n" c
      puts "$c"
    }
    
    if $brasOpts(-n) continue

    ## The command is finally executed with uplevel.
    if [catch "uplevel #0 {$cmd}" msg] {
      puts stderr \
	  "bras: a rule-command failed to execute and said"
      regsub "\[\n \]*\\(\"uplevel\" body.*" $errorInfo {} errorInfo
      puts stderr $errorInfo
      exit 1
    }
  }
  rename unknown bras.unknown
  rename unknown.orig unknown
}
########################################################################
proc bras.invokeCmd {rid Target Deps Trigger} {
  #upvar reason $_reason
  global brasRule brasOpts brasIndent
  
  ## The following variables are guaranteed to exist in the context of
  ## the command to run
  global target targets trigger deps patternTriggers preq

  ## make sure, prerequisites are available
  if {[bras.ConsiderPreqs $rid]<0} {
    return -1
  }

  ## find the command to execute
  set cmd $brasRule($rid,cmd)
  if {""=="$cmd"} {
    set _reason {}
    #set patternTriggers {}
    set cmd [bras.defaultCmd \
		 $brasRule($rid,type) $Target $Deps \
		 _reason patternTriggers]
    if {$brasOpts(-d)} {
      bras.dmsg $brasIndent $_reason
    }
    if {""=="$cmd"} {
      puts -nonewline stderr \
	  "bras(warning): no command found to make `$Target' "
      puts stderr "from `$Deps' (hope that's ok)"
      return 1
    }
  } else {
    set patternTriggers {}
    set brasRule($rid,run) 1
  }

  ## set up the context for the command
  set target $Target
  set targets $brasRule($rid,targ)
  set trigger $Trigger
  set deps $Deps
  set preq $brasRule($rid,preq)

  rename unknown unknown.orig
  rename bras.unknown unknown

  if {$brasOpts(-v)} {
    puts "\# -- running command --"
    puts "\# patternTriggers = `$patternTriggers'"
    puts "\#  target = `$target'"
    puts "\# targets = `$targets'"
    puts "\# trigger = `$trigger'"
    puts "\#    deps = `$deps'"
    puts "\#    preq = `$preq'"
    puts [string trim $cmd "\n"]
  }
 
  if {!$brasOpts(-n)} {

    if {!$brasOpts(-v) && !$brasOpts(-ve) &&
	!$brasOpts(-d) && !$brasOpts(-s)} {
      puts  "\# creating $target";
    }
    set wearehere [pwd]
    if [catch "uplevel #0 {$cmd}" msg] {
      global errorInfo
      puts stderr \
	  "bras: a rule-command failed to execute and said"
      regsub "\[\n \]*\\(\"uplevel\" body.*" $errorInfo {} errorInfo
      puts stderr $errorInfo
      exit 1
    }
    cd $wearehere
  }

  rename unknown bras.unknown
  rename unknown.orig unknown

  return 1
}

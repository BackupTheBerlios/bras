
# $Revision: 1.38 $, $Date: 2002/01/06 15:19:08 $

## tclPkgUnknown, when running this script, makes sure that
## $dir is set to the directory of this very file

set VERSION 2.1
set VERDATE 0000-00-00
package ifneeded bras $VERSION \
    [concat \
	 source [file join $dir bras.tcl] \; \
	 source [file join $dir consider.tcl] \; \
	 source [file join $dir evalCmds.tcl] \; \
	 source [file join $dir exported.tcl] \; \
	 source [file join $dir lastMinuteRule.tcl] \; \
	 source [file join $dir makeRule.tcl] \; \
	 source [file join $dir predicates.tcl] \; \
	 source [file join $dir sourceDeps.tcl] \; \
	 source [file join $dir cvsknown.tcl] \; \
 	 package provide bras $VERSION \;\
	 namespace eval bras [list set VERSION $VERSION] \; \
	 namespace eval bras [list set VERDATE $VERDATE] \;
	]

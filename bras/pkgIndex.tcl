
# $Revision: 1.37 $, $Date: 2001/12/30 09:39:22 $

## tclPkgUnknown, when running this script, makes sure that
## $dir is set to the directory of this very file

set VERSION 2.0
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

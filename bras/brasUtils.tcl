########################################################################
#
# Miscellaneous utilities.
#
# $Revision: 1.1 $, $Date: 1997/11/08 21:59:19 $
#
########################################################################

########################################################################
#
# lappendUnique -- append an element to a list if it is not already in
# there. 
#
proc lappendUnique {_list elem} {
  upvar $_list list
  
  if {-1==[lsearch -exact $list $elem]} {
    lappend list $elem
  }
}
########################################################################
#
# concatUnique
#
proc concatUnique {_list newElems} {
  upvar $_list list
  
  foreach elem $newElems {
    if {-1!=[lsearch -exact $list $elem]} continue
    lappend list $elem
  }
}
########################################################################

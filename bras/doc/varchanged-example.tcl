##############################################################
# $Revision: 1.1 $, $Date: 2000/05/27 18:48:01 $
##############################################################
Always all {resultA resultB} {
}

Make resultB {
  [or [older $target inputB] [varchanged ::paramB $target.cache]]
} {
  echo $paramB >$target
  echo "set paramB $paramB" >$target.cache
}

Exist inputB {
  touch $target
}


Make resultA {
  [or [older $target inputA] [varchanged ::paramA $target.cache]]
} {
  echo $paramA >resultA
  echo "set paramA $paramA" >$target.cache
}

Exist inputA {
  touch $target
}

Make {::paramA ::paramB} {[notinitialized $targets]} {
  include params
}
##############################################################

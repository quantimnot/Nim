
when vm and true: # `vm` is a normal constant expression that can be combined with others
  proc ambiguous = discard
else:
  template ambiguous: untyped = discard
ambiguous()

template isInVm: untyped =
  when vm: true
  else: false
static: doAssert isInVm
doAssert not isInVm

proc contextAwareProc(): string =
  when vm: "compile-time result"
  else: "runtime result"
static: doAssert contextAwareProc() == "compile-time result"
doAssert contextAwareProc() == "runtime result"

doAssert vm == false
static: doAssert vm == true

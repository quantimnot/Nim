# Test for module/type name ambiguity resolution in template parameters
# This tests the fix for issue where template arguments of type `typedesc`
# incorrectly resolved to module symbols instead of type symbols when
# both have the same name.

import ./MyType

block: # Constrained template
  template test(T: typedesc): string = $T
  doAssert test(MyType) == "MyType"

block: # Unconstrained template
  template test2(T): string = $T
  doAssert test2(MyType) == "MyType"

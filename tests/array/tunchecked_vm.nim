proc testUncheckedArrayVM() =
  # Test basic reading
  var arr = [1'u8, 2, 3, 4, 5]
  let p = cast[ptr UncheckedArray[uint8]](addr arr[0])
  doAssert p[0] == 1'u8
  doAssert p[1] == 2'u8
  doAssert p[2] == 3'u8

  # Test address calculation
  let addr0 = cast[int](addr p[0])
  let addr1 = cast[int](addr p[1])
  doAssert addr0 != addr1
  doAssert addr1 - addr0 == sizeof(uint8), $(addr1 - addr0)

  # Test writing
  p[0] = 42'u8
  doAssert p[0] == 42'u8

# Test compile-time evaluation including writes
const testConstExpr = block:
  var arr = [1, 2, 3, 4, 5]
  let p = cast[ptr UncheckedArray[int]](addr arr[0])
  p[1] = 99  # Test VM write operation
  p[0]  # Return original first element

static: testUncheckedArrayVM()
doAssert testConstExpr == 1, $testConstExpr

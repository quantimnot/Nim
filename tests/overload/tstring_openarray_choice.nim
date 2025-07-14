# This used to fail with: "type mismatch: got <string> but expected one of: proc testChoice(x: openArray[char] | int)"

proc testChoice(x: openArray[char] | int) =
  discard

# This line used to cause a compilation error - now it should work!
testChoice("hello")

echo "Original bug is fixed! No more type mismatch error."
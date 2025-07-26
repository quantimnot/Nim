
template nonOverlapping: untyped =
  var src = [1'u8, 2, 3, 4, 5, 6, 7, 8]
  var dest = [0'u8, 0, 0, 0, 0, 0, 0, 0]
  moveMem(addr dest[0], addr src[0], 8)
  doAssert dest == [1'u8, 2, 3, 4, 5, 6, 7, 8], $dest
nonOverlapping()
static: nonOverlapping()

template overlapDestAfterSource: untyped =
  var data = [1'u8, 2, 3, 4, 5, 6, 7, 8]
  # Copy [1,2,3,4] to position starting at index 2
  # This overlaps: source is 0..3, dest is 2..5
  moveMem(addr data[2], addr data[0], 4)
  doAssert data == [1'u8, 2, 1, 2, 3, 4, 7, 8], $data
overlapDestAfterSource()
static: overlapDestAfterSource()

template overlapDestBeforeSource: untyped =
  var data = [1'u8, 2, 3, 4, 5, 6, 7, 8]
  # Copy [3,4,5,6] to position starting at index 1
  # This overlaps: source is 2..5, dest is 1..4
  moveMem(addr data[1], addr data[2], 4)
  doAssert data == [1'u8, 3, 4, 5, 6, 6, 7, 8], $data
overlapDestBeforeSource()
static: overlapDestBeforeSource()

template completeOverlap: untyped =
  var data = [1'u8, 2, 3, 4, 5]
  var original = data
  moveMem(addr data[0], addr data[0], 5)
  doAssert data == original, $data
completeOverlap()
static: completeOverlap()

template zeroSize: untyped =
  var data = [1'u8, 2, 3]
  var original = data
  moveMem(addr data[1], addr data[0], 0)
  doAssert data == original, $data
zeroSize()
static: zeroSize()

template singleByte: untyped =
  var data = [1'u8, 2, 3]
  moveMem(addr data[2], addr data[0], 1)
  doAssert data == [1'u8, 2, 1], $data
singleByte()
static: singleByte()

template slidingWindow: untyped =
  var data = [1'u8, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  # Slide a 5-byte window by 2 positions to the right
  moveMem(addr data[2], addr data[0], 5)
  doAssert data == [1'u8, 2, 1, 2, 3, 4, 5, 8, 9, 10], $data
slidingWindow()
static: slidingWindow()

# template differentTypes: untyped =
#   type Point = object
#     x, y: int
#   var points = [Point(x: 1, y: 2), Point(x: 3, y: 4), Point(x: 5, y: 6)]
#   # Move middle point to first position
#   moveMem(addr points[0], addr points[1], sizeof(Point))
#   doAssert points[0] == Point(x: 3, y: 4)
#   doAssert points[1] == Point(x: 3, y: 4)  # Original data preserved
#   doAssert points[2] == Point(x: 5, y: 6)
# differentTypes()
# static: differentTypes()

template arrayShift: untyped =
  const size = 100
  var data: array[size, int]
  for i in 0..<size:
    data[i] = i
  # Shift entire array one position to the right (losing last element)
  moveMem(addr data[1], addr data[0], (size - 1) * sizeof(int))
  # Verify shift
  for i in 1..<size:
    doAssert data[i] == i - 1
  # First element unchanged
  doAssert data[0] == 0
arrayShift()
static: arrayShift()

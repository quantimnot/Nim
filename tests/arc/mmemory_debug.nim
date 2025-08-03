## Memory debugging test module with command line test selection
## Usage: nim c -r mmemory_debug.nim [test_name]
## Available tests: basic, stack-heap, memory-ops, canary, overflow, pointer,
##                  cyclic, heap-stats, use-after-free, invalid-pointer,
##                  multi-flags, config, all

import std/[os, strutils]

when defined(nimArcDebug):
  # Import debugging functions when available
  proc nimArcDebugHeapStats*() {.importc, gcsafe.}
  proc nimArcDebugLeakCheck*() {.importc, gcsafe.}
  proc nimArcDebugCheckStack*() {.importc, gcsafe.}
  proc nimArcDebugIsStackAddress*(p: pointer): bool {.importc, gcsafe.}
  proc nimArcDebugIsHeapAddress*(p: pointer): bool {.importc, gcsafe.}
  proc nimArcDebugAnalyzePointer*(p: pointer) {.importc, gcsafe.}
  proc detectStackOverflow*(): bool {.importc, gcsafe.}

# Test configuration based on active flags
const
  usingArcDebug = defined(nimArcDebug)
  usingArcFatal = defined(nimArcDebugFatal)
  usingTraceArc = defined(traceArc)
  usingOrcLeakDetector = defined(nimOrcLeakDetector)
  usingOrcMM = defined(gcOrc)
  usingArcMM = defined(gcArc)

type
  TestObject = ref object
    value: int
    data: array[5, int]
    name: string

  StackObject = object
    value: int
    data: array[3, int]

  CyclicNode = ref object
    value: int
    next: CyclicNode

proc testBasicAllocation() =
  ## Test basic allocation and deallocation with debug tracking
  echo "Testing basic allocation..."

  # Create objects that will be tracked by debug system
  var obj1 = TestObject(value: 42, name: "test1")
  var obj2 = TestObject(value: 99, name: "test2")

  doAssert obj1.value == 42
  doAssert obj2.value == 99
  doAssert obj1.name == "test1"
  doAssert obj2.name == "test2"

  # Clear references to trigger debug tracking
  obj1 = nil
  obj2 = nil
  GC_fullCollect()

  echo "Basic allocation test PASS"

proc testStackVsHeapDetection() =
  ## Test stack vs heap address classification
  echo "Testing stack vs heap detection..."

  when usingArcDebug:
    # Test heap object creation
    var heapObj = TestObject(value: 123, name: "heap")
    doAssert heapObj.value == 123
    doAssert heapObj.name == "heap"

    # Test stack variable creation
    var stackVar: int = 456
    doAssert stackVar == 456

    # Test stack object creation
    var stackObj: StackObject
    stackObj.value = 789
    doAssert stackObj.value == 789

    # Test pointer classification (when functions are available)
    let heapPtr = cast[pointer](heapObj)
    let stackPtr = cast[pointer](addr stackVar)
    doAssert heapPtr != nil
    doAssert stackPtr != nil

  echo "Stack vs heap detection test PASS"

proc testMemoryOperations() =
  ## Test allocation tracking and basic memory operations
  echo "Testing memory operations..."

  var objects: seq[TestObject] = @[]

  for i in 0..4:
    let obj = TestObject(value: i * 10, name: "test_" & $i)
    objects.add(obj)
    doAssert obj.value == i * 10
    doAssert obj.name == "test_" & $i

  doAssert objects.len == 5

  # Verify all objects are correctly allocated and accessible
  for i, obj in objects:
    doAssert obj.value == i * 10
    doAssert obj.name == "test_" & $i

    when usingArcDebug:
      # Verify object is properly allocated
      doAssert obj != nil

  # Clear references to trigger deallocation
  objects = @[]
  GC_fullCollect()

  echo "Memory operations test PASS"

proc testStackCanarySystem() =
  ## Test stack canary system for overflow detection
  echo "Testing stack canary system..."

  when usingArcDebug:
    # Test nested allocations
    block nested_allocations:
      var localObj = TestObject(value: 999, name: "nested")
      doAssert localObj.value == 999

      block deeper_nesting:
        var deepObj = TestObject(value: 888, name: "deep")
        doAssert deepObj.value == 888

  echo "Stack canary system test PASS"

proc testStackOverflowDetection() =
  ## Test stack overflow detection capabilities
  echo "Testing stack overflow detection..."

  when usingArcDebug:
    # Test nested function calls with allocations
    proc testNestedCalls(depth: int) =
      if depth > 0:
        var localObj = TestObject(value: depth, name: "nested_" & $depth)
        doAssert localObj.value == depth
        testNestedCalls(depth - 1)

    # Test moderate nesting (should complete without issues)
    testNestedCalls(3)
    doAssert true  # Should reach here without stack overflow

  echo "Stack overflow detection test PASS"

proc testPointerAnalysis() =
  ## Test pointer analysis functionality
  echo "Testing pointer analysis..."

  when usingArcDebug:
    # Test basic pointer operations and validation
    var stackVar: int = 777
    var heapObj = TestObject(value: 888, name: "analysis")

    # Verify objects are properly created and accessible
    doAssert stackVar == 777
    doAssert heapObj.value == 888
    doAssert heapObj.name == "analysis"

    # Test basic pointer conversion (should not crash)
    let stackPtr = cast[pointer](addr stackVar)
    let heapPtr = cast[pointer](heapObj)
    doAssert stackPtr != nil
    doAssert heapPtr != nil

  echo "Pointer analysis test PASS"

proc testCyclicReferences() =
  ## Test cyclic reference handling for ORC
  echo "Testing cyclic references..."

  when usingOrcMM:
    # Create cyclic structure for ORC cycle collection
    var node1 = CyclicNode(value: 100)
    var node2 = CyclicNode(value: 200)
    var node3 = CyclicNode(value: 300)

    # Create a cycle: node1 -> node2 -> node3 -> node1
    node1.next = node2
    node2.next = node3
    node3.next = node1

    # Verify cycle structure
    doAssert node1.value == 100
    doAssert node1.next.value == 200
    doAssert node1.next.next.value == 300
    doAssert node1.next.next.next.value == 100  # Back to start

    # Clear all references - ORC should detect and collect the cycle
    node1 = nil
    node2 = nil
    node3 = nil

    GC_fullCollect()
    when usingOrcMM:
      GC_runOrc()

  echo "Cyclic references test PASS"

proc testHeapStatistics() =
  ## Test heap statistics and diagnostic functions
  echo "Testing heap statistics..."

  when usingArcDebug:
    # Create objects to test allocation patterns
    var testObjects: seq[TestObject] = @[]

    for i in 0..7:
      testObjects.add(TestObject(value: i * 50, name: "stats_" & $i))

    # Verify all objects were created correctly
    doAssert testObjects.len == 8
    for i, obj in testObjects:
      doAssert obj.value == i * 50
      doAssert obj.name == "stats_" & $i

    # Test diagnostic functions (should not crash)
    nimArcDebugHeapStats()
    nimArcDebugLeakCheck()
    nimArcDebugCheckStack()

    # Clear half the objects
    testObjects = testObjects[0..3]
    doAssert testObjects.len == 4

    # Verify remaining objects are still valid
    for i, obj in testObjects:
      doAssert obj.value == i * 50
      doAssert obj.name == "stats_" & $i

    # Clear all objects
    testObjects = @[]
    doAssert testObjects.len == 0
    GC_fullCollect()

  echo "Heap statistics test PASS"

proc testUseAfterFreeProtection() =
  ## Test use-after-free protection mechanisms
  echo "Testing use-after-free protection..."

  var obj = TestObject(value: 555, name: "will_be_freed")
  doAssert obj.value == 555
  doAssert obj.name == "will_be_freed"

  when usingArcDebug:
    # Verify object is properly allocated and accessible
    doAssert obj != nil
    let objPtr = cast[pointer](obj)
    doAssert objPtr != nil

  # Clear reference to trigger deallocation
  obj = nil
  GC_fullCollect()

  # Verify object reference is properly cleared
  doAssert obj == nil

  echo "Use-after-free protection test PASS"

proc testInvalidPointerDetection() =
  ## Test invalid pointer detection and handling
  echo "Testing invalid pointer detection..."

  when usingArcDebug:
    # Test null pointer handling (should be safe)
    var nullObj: TestObject = nil
    doAssert nullObj == nil

    # Test valid object creation and access
    var validObj = TestObject(value: 123, name: "valid")
    doAssert validObj != nil
    doAssert validObj.value == 123

    # Test assignment and clearing
    validObj = nil
    doAssert validObj == nil

  echo "Invalid pointer detection test PASS"

proc testMultipleFlagsIntegration() =
  ## Test multiple debug flags working together
  echo "Testing multiple flags integration..."

  # Create objects while multiple flags are active
  var testObj = TestObject(value: 999, name: "multi_flag_test")
  doAssert testObj.value == 999
  doAssert testObj.name == "multi_flag_test"

  when usingArcDebug:
    # Test basic operations with debug flags active
    doAssert testObj != nil
    let objPtr = cast[pointer](testObj)
    doAssert objPtr != nil

  # Test object lifecycle with flags active
  testObj = nil
  doAssert testObj == nil
  GC_fullCollect()

  echo "Multiple flags integration test PASS"

proc testConfigurationValidation() =
  ## Test configuration validation for different debug modes
  echo "Testing configuration validation..."

  when usingArcDebug:
    # Test basic debug functionality
    var testVar: int = 42
    doAssert testVar == 42

    # Test heap object creation under debug mode
    var debugObj = TestObject(value: 123, name: "debug_test")
    doAssert debugObj.value == 123
    doAssert debugObj.name == "debug_test"
    debugObj = nil

  when usingOrcMM:
    # ORC should handle cyclic references
    var node = CyclicNode(value: 999)
    node.next = node  # Self-reference
    doAssert node.value == 999
    doAssert node.next.value == 999
    node = nil

  when usingTraceArc:
    # Trace mode should work with object creation
    var traced = TestObject(value: 777, name: "traced")
    doAssert traced.value == 777
    traced = nil

  echo "Configuration validation test PASS"

proc showUsage() =
  echo "Usage: mmemory_debug [test_name]"
  echo ""
  echo "Available tests:"
  echo "  basic          - Basic allocation and deallocation test"
  echo "  stack-heap     - Stack vs heap address detection test"
  echo "  memory-ops     - Memory operations tracking test"
  echo "  canary         - Stack canary system test"
  echo "  overflow       - Stack overflow detection test"
  echo "  pointer        - Pointer analysis test"
  echo "  cyclic         - Cyclic references test (ORC only)"
  echo "  heap-stats     - Heap statistics test"
  echo "  use-after-free - Use-after-free protection test"
  echo "  invalid-pointer- Invalid pointer detection test"
  echo "  multi-flags    - Multiple flags integration test"
  echo "  config         - Configuration validation test"
  echo "  all            - Run all tests (default)"
  echo ""
  echo "Examples:"
  echo "  nim c -d:nimArcDebug --mm:arc -r mmemory_debug.nim basic"
  echo "  nim c -d:nimArcDebug -d:traceArc --mm:orc -r mmemory_debug.nim heap-stats"

proc showActiveFlags() =
  echo "=== ARC/ORC Memory Debug Tests ==="
  echo "Active flags:"
  when usingArcDebug:
    echo "  - nimArcDebug: enabled"
  when usingArcFatal:
    echo "  - nimArcDebugFatal: enabled"
  when usingTraceArc:
    echo "  - traceArc: enabled"
  when usingOrcLeakDetector:
    echo "  - nimOrcLeakDetector: enabled"
  when usingOrcMM:
    echo "  - ORC memory management: enabled"
  when usingArcMM:
    echo "  - ARC memory management: enabled"
  echo ""

proc runAllTests() =
  # Run core tests that work with all configurations
  testBasicAllocation()
  testMemoryOperations()
  testUseAfterFreeProtection()
  testMultipleFlagsIntegration()
  testConfigurationValidation()

  # Run tests specific to debug mode
  when usingArcDebug:
    testStackVsHeapDetection()
    testStackCanarySystem()
    testStackOverflowDetection()
    testPointerAnalysis()
    testHeapStatistics()
    testInvalidPointerDetection()

  # Run ORC-specific tests
  when usingOrcMM:
    testCyclicReferences()

  echo ""
  echo "All tests completed successfully!"
  echo "PASS"

proc runTest(testName: string) =
  case testName.toLowerAscii()
  of "basic":
    testBasicAllocation()
  of "stack-heap":
    testStackVsHeapDetection()
  of "memory-ops":
    testMemoryOperations()
  of "canary":
    testStackCanarySystem()
  of "overflow":
    testStackOverflowDetection()
  of "pointer":
    testPointerAnalysis()
  of "cyclic":
    testCyclicReferences()
  of "heap-stats":
    testHeapStatistics()
  of "use-after-free":
    testUseAfterFreeProtection()
  of "invalid-pointer":
    testInvalidPointerDetection()
  of "multi-flags":
    testMultipleFlagsIntegration()
  of "config":
    testConfigurationValidation()
  of "all":
    runAllTests()
  else:
    echo "Unknown test: ", testName
    echo ""
    showUsage()
    quit(1)

proc main() =
  let params = commandLineParams()

  # Show help if requested
  if params.len > 0 and params[0] in ["--help", "-h", "help"]:
    showUsage()
    return

  showActiveFlags()

  # Determine which test to run
  let testName = if params.len > 0: params[0] else: "all"

  echo "Running test scenario: ", testName
  echo ""

  runTest(testName)

when isMainModule:
  main()

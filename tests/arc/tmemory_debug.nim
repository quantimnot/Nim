discard """
description: "Comprehensive ARC/ORC memory debugging test suite with output validation"
"""

## Test runner that executes memory debug tests with different flag combinations
## and validates that expected debug output is produced

import std/[osproc, strutils, os]

type
  TestConfig = object
    name: string
    flags: seq[string]
    expectedOutputs: seq[string]  # Substrings that must be present
    forbiddenOutputs: seq[string] # Substrings that must NOT be present

proc runTest(config: TestConfig): bool =
  ## Run a test configuration and validate output

  # Build the command
  var cmd = @["nim", "c", "--hints:off", "-r"]
  cmd.add(config.flags)
  cmd.add(currentSourcePath().parentDir / "mmemory_debug.nim")

  let cmdStr = cmd.join(" ")

  # Execute the command
  let (output, exitCode) = execCmdEx(cmdStr)

  if exitCode != 0:
    return false

  # Check for expected outputs
  for expected in config.expectedOutputs:
    if expected notin output:
      return false

  # Check for forbidden outputs
  for forbidden in config.forbiddenOutputs:
    if forbidden in output:
      return false

  return true


let testConfigs = @[
  # Test 1: Basic ARC with debug
  TestConfig(
    name: "ARC with nimArcDebug",
    flags: @["--mm:arc", "-d:nimArcDebug"],
    expectedOutputs: @[
      "nimArcDebug: enabled",
      "Testing basic allocation",
      "Testing stack vs heap detection",
      "Testing heap statistics",
      "PASS",
      "All tests completed successfully"
    ],
    forbiddenOutputs: @["FAIL", "Error:", "Exception"]
  ),

  # Test 2: ARC with debug and trace
  TestConfig(
    name: "ARC with nimArcDebug + traceArc",
    flags: @["--mm:arc", "-d:nimArcDebug", "-d:traceArc"],
    expectedOutputs: @[
      "nimArcDebug: enabled",
      "traceArc: enabled",
      "[nimNewObj]",  # Should see trace output
      "PASS"
    ],
    forbiddenOutputs: @["FAIL"]
  ),

  # Test 3: ARC with fatal debug mode
  TestConfig(
    name: "ARC with nimArcDebug + nimArcDebugFatal",
    flags: @["--mm:arc", "-d:nimArcDebug", "-d:nimArcDebugFatal"],
    expectedOutputs: @[
      "nimArcDebug: enabled",
      "nimArcDebugFatal: enabled",
      "PASS"
    ],
    forbiddenOutputs: @["FAIL"]
  ),

  # Test 4: ORC with debug
  TestConfig(
    name: "ORC with nimArcDebug",
    flags: @["--mm:orc", "-d:nimArcDebug"],
    expectedOutputs: @[
      "nimArcDebug: enabled",
      "ORC memory management: enabled",
      "Testing cyclic references",
      "PASS"
    ],
    forbiddenOutputs: @["FAIL"]
  ),

  # Test 5: ORC with debug and trace
  TestConfig(
    name: "ORC with nimArcDebug + traceArc",
    flags: @["--mm:orc", "-d:nimArcDebug", "-d:traceArc"],
    expectedOutputs: @[
      "nimArcDebug: enabled",
      "traceArc: enabled",
      "ORC memory management: enabled",
      "Testing cyclic references",
      "PASS"
    ],
    forbiddenOutputs: @["FAIL"]
  ),

  # Test 6: Verify heap statistics output
  TestConfig(
    name: "ARC debug heap statistics validation",
    flags: @["--mm:arc", "-d:nimArcDebug"],
    expectedOutputs: @[
      "=== HEAP STATISTICS ===",
      "Total allocations:",
      "Total deallocations:",
      "Current objects:",
      "=== END HEAP STATISTICS ===",
      "PASS"
    ],
    forbiddenOutputs: @["FAIL"]
  ),

  # Test 7: Verify memory operations produce debug output
  TestConfig(
    name: "Memory operations debug output",
    flags: @["--mm:arc", "-d:nimArcDebug", "-d:traceArc"],
    expectedOutputs: @[
      "[Allocated]",  # From allocation tracking
      "[Freed]",      # From deallocation tracking
      "Testing memory operations",
      "PASS"
    ],
    forbiddenOutputs: @["FAIL"]
  ),

  # Test 8: Verify flag combinations work correctly
  TestConfig(
    name: "Multiple flags integration test",
    flags: @["--mm:arc", "-d:nimArcDebug", "-d:traceArc", "-d:nimArcDebugFatal"],
    expectedOutputs: @[
      "nimArcDebug: enabled",
      "traceArc: enabled",
      "nimArcDebugFatal: enabled",
      "Testing multiple flags integration",
      "Multiple flags integration test PASS",
      "PASS"
    ],
    forbiddenOutputs: @["FAIL", "Error"]
  )
]

var failed = false

for config in testConfigs:
  if not runTest(config):
    failed = true

if failed:
  quit(QuitFailure)

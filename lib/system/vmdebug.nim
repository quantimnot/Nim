# VM Debugging Aids - Available in static contexts
# These utilities help debug VM internal representations during compile-time execution

import std/[strformat, strutils]

# VM debugging builtins - these are registered in compiler/vmops.nim
proc vmDumpContext*() {.compileTime.} =
  ## Dump current VM context including globals and their values
  discard

proc vmDumpNode*(node: auto, depth: int = 2) {.compileTime.} =
  ## Recursively dump a node's internal AST structure
  discard

proc vmTraceUncheckedArray*(address: int, operation: string = "access") {.compileTime.} =
  ## Trace UncheckedArray operations to understand address resolution
  discard

proc vmNodeToYaml*(node: auto): string {.compileTime.} =
  ## Convert a node to YAML representation showing internal structure
  discard

proc vmNodeKind*(node: auto): string {.compileTime.} =
  ## Get the node kind name (nkIntLit, nkSym, etc.)
  discard

proc vmNodeType*(node: auto): string {.compileTime.} =
  ## Get the node's type information
  discard

proc vmTraceAssignment*(regKind: string, nodeKind: string, description: string) {.compileTime.} =
  ## Trace VM register assignments that might cause reference counting issues
  discard

proc vmTraceRefCounting*(nodeAddr: int, nodeKind: string, operation: string) {.compileTime.} =
  ## Trace reference counting operations on VM nodes
  discard

proc vmTraceWriteField*(fieldName: string, srcKind: string, destKind: string) {.compileTime.} =
  ## Trace writeField operations that might crash
  discard

# Convenience templates for easier usage
template vmNodeYaml*(node: typed) =
  ## Print YAML representation of a node
  echo vmNodeToYaml(node)

template vmNodeInfo*(node: typed) =
  ## Print basic node information
  echo "Node Kind: ", vmNodeKind(node)
  echo "Node Type: ", vmNodeType(node)

template vmTrace*(msg: string) =
  ## Print a trace message with VM context
  static:
    echo "[VM-TRACE] ", msg

# Advanced debugging templates
template vmDebugPointerAnalysis*(p: untyped) =
  ## Analyze a pointer and trace its VM representation
  static:
    let address = cast[int](p)
    echo "=== VM Pointer Analysis ==="
    echo "Pointer Value: 0x", address.toHex
    vmdebugTraceUncheckedArray(address, "pointer_analysis")
    echo "=========================="

template vmDebugArrayAccess*(arr: untyped, index: int) =
  ## Debug array element access in VM
  static:
    let elemPtr = addr arr[index]
    let address = cast[int](elemPtr)
    echo "=== VM Array Access Debug ==="
    echo "Array: ", typeof(arr)
    echo "Index: ", index
    echo "Element Address: 0x", address.toHex
    vmdebugTraceUncheckedArray(address, "array_access[" & $index & "]")
    echo "============================="

template vmDebugUncheckedArray*(p: untyped, maxElements: int = 5) =
  ## Debug UncheckedArray pointer and try to read elements safely
  static:
    let address = cast[int](p)
    echo "=== VM UncheckedArray Debug ==="
    echo "UncheckedArray Pointer: 0x", address.toHex
    vmdebugTraceUncheckedArray(address, "unchecked_array_debug")
    echo "==============================="
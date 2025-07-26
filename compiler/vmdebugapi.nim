# VM Debug API Implementation
# Provides debugging functions that can be called from static contexts

import ast, types, msgs, options, vmdef
import std/[strformat, strutils, sequtils]
when defined nimPreviewSlimSystem:
  import std/formatfloat

# Global VM context for debugging
var currentVMContext*: PCtx = nil

proc setCurrentVMContext*(ctx: PCtx) =
  ## Set the current VM context for debugging
  currentVMContext = ctx

proc getCurrentVMContext*(): pointer {.exportc.} =
  ## Get current VM context for debugging
  result = cast[pointer](currentVMContext)

proc getVMGlobalNodes*(ctx: pointer): seq[pointer] {.exportc.} =
  ## Get all global variable nodes from VM context
  let vmCtx = cast[PCtx](ctx)
  if vmCtx == nil:
    return @[]
  
  result = newSeq[pointer](vmCtx.globals.len)
  for i, global in vmCtx.globals:
    result[i] = cast[pointer](global)

proc getVMRegisters*(ctx: pointer): seq[pointer] {.exportc.} =
  ## Get current VM registers (simplified for debugging)
  # This would need access to current stack frame
  # For now, return empty - would need more VM internals access
  result = @[]

proc nodeToYamlRepr*(node: pointer): string {.exportc.} =
  ## Convert a PNode to YAML representation
  let pnode = cast[PNode](node)
  if pnode == nil:
    return "null"
  
  result = "node:\n"
  result.add &"  kind: {pnode.kind}\n"
  result.add &"  address: 0x{cast[int](pnode):08X}\n"
  
  if pnode.typ != nil:
    result.add &"  type:\n"
    result.add &"    kind: {pnode.typ.kind}\n"
    if pnode.typ.sym != nil:
      result.add &"    name: \"{pnode.typ.sym.name.s}\"\n"
  else:
    result.add &"  type: null\n"
  
  result.add &"  flags: {pnode.flags}\n"
  
  case pnode.kind:
  of nkIntLit, nkInt8Lit, nkInt16Lit, nkInt32Lit, nkInt64Lit,
     nkUIntLit, nkUInt8Lit, nkUInt16Lit, nkUInt32Lit, nkUInt64Lit:
    result.add &"  intVal: {pnode.intVal}\n"
  of nkFloatLit, nkFloat32Lit, nkFloat64Lit, nkFloat128Lit:
    result.add &"  floatVal: {pnode.floatVal}\n"
  of nkStrLit..nkTripleStrLit:
    result.add &"  strVal: \"{pnode.strVal}\"\n"
  of nkSym:
    if pnode.sym != nil:
      result.add &"  sym:\n"
      result.add &"    name: \"{pnode.sym.name.s}\"\n"
      result.add &"    kind: {pnode.sym.kind}\n"
  else:
    discard
  
  if pnode.len > 0:
    result.add &"  children: [{pnode.len}]\n"
    for i in 0..<min(pnode.len, 10):  # Limit output
      let child = pnode[i]
      if child != nil:
        result.add &"    - index: {i}\n"
        result.add &"      kind: {child.kind}\n"
        result.add &"      address: 0x{cast[int](child):08X}\n"
        if child.kind in {nkIntLit..nkUInt64Lit}:
          result.add &"      value: {child.intVal}\n"
        elif child.kind in {nkStrLit..nkTripleStrLit}:
          result.add &"      value: \"{child.strVal}\"\n"
      else:
        result.add &"    - index: {i}\n"
        result.add &"      kind: null\n"
    if pnode.len > 10:
      result.add &"    # ... and {pnode.len - 10} more children\n"
  else:
    result.add &"  children: []\n"

proc getNodeKindName*(node: pointer): string {.exportc.} =
  ## Get the kind name of a node
  let pnode = cast[PNode](node)
  if pnode == nil:
    return "null"
  result = $pnode.kind

proc getNodeTypeName*(node: pointer): string {.exportc.} =
  ## Get the type name of a node
  let pnode = cast[PNode](node)
  if pnode == nil or pnode.typ == nil:
    return "null"
  result = $pnode.typ.kind
  if pnode.typ.sym != nil:
    result.add &"({pnode.typ.sym.name.s})"

proc getNodeIntValue*(node: pointer): BiggestInt {.exportc.} =
  ## Get integer value from a node
  let pnode = cast[PNode](node)
  if pnode == nil:
    return 0
  case pnode.kind:
  of nkIntLit, nkInt8Lit, nkInt16Lit, nkInt32Lit, nkInt64Lit,
     nkUIntLit, nkUInt8Lit, nkUInt16Lit, nkUInt32Lit, nkUInt64Lit:
    result = pnode.intVal
  else:
    result = 0

proc getNodeStrValue*(node: pointer): string {.exportc.} =
  ## Get string value from a node
  let pnode = cast[PNode](node)
  if pnode == nil:
    return ""
  case pnode.kind:
  of nkStrLit..nkTripleStrLit:
    result = pnode.strVal
  else:
    result = ""

proc getNodeLength*(node: pointer): int {.exportc.} =
  ## Get the number of children in a node
  let pnode = cast[PNode](node)
  if pnode == nil:
    return 0
  result = pnode.len

proc getNodeChildAt*(node: pointer, idx: int): pointer {.exportc.} =
  ## Get child node at index
  let pnode = cast[PNode](node)
  if pnode == nil or idx < 0 or idx >= pnode.len:
    return nil
  result = cast[pointer](pnode[idx])

# Enhanced debugging functions
proc vmDebugDumpContext*(ctx: PCtx) =
  ## Dump VM context for debugging
  echo "=== VM Context Debug Dump ==="
  var actualCtx = ctx
  if actualCtx == nil:
    echo "Context: nil (using current VM context)"
    if currentVMContext != nil:
      actualCtx = currentVMContext
    else:
      echo "No VM context available"
      echo "=========================="
      return
  
  echo &"Context Address: 0x{cast[int](actualCtx):08X}"
  echo &"Globals Count: {actualCtx.globals.len}"
  
  for i, global in actualCtx.globals:
    if global != nil:
      echo &"  Global[{i}]: {global.kind} at 0x{cast[int](global):08X}"
      if global.kind == nkBracket:
        echo &"    Array length: {global.len}"
        for j in 0..<min(global.len, 5):
          if global[j] != nil:
            case global[j].kind:
            of nkIntLit..nkUInt64Lit:
              echo &"      [{j}]: {global[j].intVal}"
            else:
              echo &"      [{j}]: {global[j].kind}"
    else:
      echo &"  Global[{i}]: nil"
  
  echo "=========================="

proc vmDebugDumpNode*(node: PNode, depth: int = 0) =
  ## Recursively dump a node structure
  let indent = "  ".repeat(depth)
  if node == nil:
    echo &"{indent}Node: nil"
    return
  
  echo &"{indent}Node: {node.kind} at 0x{cast[int](node):08X}"
  
  if node.typ != nil:
    echo &"{indent}  Type: {node.typ.kind}"
  
  case node.kind:
  of nkIntLit..nkUInt64Lit:
    echo &"{indent}  Value: {node.intVal}"
  of nkStrLit..nkTripleStrLit:
    echo &"{indent}  Value: \"{node.strVal}\""
  of nkFloatLit..nkFloat128Lit:
    echo &"{indent}  Value: {node.floatVal}"
  else:
    discard
  
  if node.len > 0 and depth < 3:  # Limit recursion depth
    echo &"{indent}  Children: {node.len}"
    for i in 0..<min(node.len, 5):  # Limit children shown
      vmDebugDumpNode(node[i], depth + 1)
    if node.len > 5:
      echo &"{indent}    ... and {node.len - 5} more children"

proc vmDebugTraceUncheckedArray*(address: BiggestInt, operation: string) =
  ## Trace UncheckedArray operations for debugging
  if address >= 1 and address <= 1000:
    echo &"[VM-DEBUG] {operation}: synthetic address {address} (likely array index {address-1})"
  else:
    echo &"[VM-DEBUG] {operation}: real address 0x{address:08X}"

proc vmDebugTraceAssignment*(regKind: string, nodeKind: string, description: string) =
  ## Trace VM register assignments that might cause reference counting issues
  echo &"[VM-ASSIGN] {description}: {regKind} <- {nodeKind}"

proc vmDebugTraceRefCounting*(nodeAddr: BiggestInt, nodeKind: string, operation: string) =
  ## Trace reference counting operations on VM nodes
  echo &"[VM-REFCOUNT] {operation} on {nodeKind} at 0x{nodeAddr:08X}"

proc vmDebugTraceWriteField*(fieldName: string, srcKind: string, destKind: string) =
  ## Trace writeField operations that might crash
  echo &"[VM-WRITEFIELD] {fieldName}: {srcKind} -> {destKind}"
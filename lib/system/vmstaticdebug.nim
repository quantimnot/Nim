# Static VM Debugging Aids
# These work only in static contexts and provide debugging information
# about the internal VM representation of nodes and data structures

import std/[strformat, strutils]

# Core debugging templates that work in static contexts
template vmDebugTrace*(msg: string) =
  ## Print a trace message in static contexts only
  echo "[VM-DEBUG] " & msg

template vmDebugDump*(node: untyped) =
  ## Dump basic information about a node in static contexts
  echo "=== VM Node Debug ==="
  echo "Address: 0x", cast[int](unsafeAddr node).toHex
  echo "Repr: ", repr(node)
  echo "Type: ", $typeof(node)
  echo "===================="

template vmDebugArray*(arr: untyped) =
  ## Dump array contents with addresses in static contexts
  echo "=== VM Array Debug ==="
  echo "Array Type: ", $typeof(arr)
  echo "Array Address: 0x", cast[int](unsafeAddr arr).toHex
  echo "Array Length: ", arr.len
  echo "Elements:"
  for i in 0..<min(arr.len, 10):  # Limit output
    echo &"  [{i}]: {arr[i]} @ 0x{cast[int](unsafeAddr arr[i]).toHex}"
  if arr.len > 10:
    echo &"  ... and {arr.len - 10} more elements"
  echo "====================="

template vmDebugPointer*(p: untyped) =
  ## Dump pointer information in static contexts
  static:
    echo "=== VM Pointer Debug ==="
    echo "Pointer Type: ", $typeof(p)
    echo "Pointer Value: 0x", cast[int](p).toHex
    let address = cast[int](p)
    if address >= 1 and address <= 1000:
      echo "Address Type: Synthetic (index ", address - 1, ")"
    elif address == 0:
      echo "Address Type: NULL"
    else:
      echo "Address Type: Real memory address"
    echo "======================"

template vmDebugUncheckedArray*(p: untyped, maxElements: int = 5) =
  ## Debug UncheckedArray pointer and try to read elements safely
  static:
    echo "=== VM UncheckedArray Debug ==="
    echo "UncheckedArray Pointer: 0x", cast[int](p).toHex
    
    let address = cast[int](p)
    if address >= 1 and address <= 1000:
      echo "Address Type: Synthetic (likely array index ", address - 1, ")"
      echo "This suggests the pointer was stored and converted to synthetic address"
    elif address == 0:
      echo "Address Type: NULL pointer - would crash if dereferenced"
    else:
      echo "Address Type: Real memory address"
    
    # Only try to read if it looks like a valid address
    if address != 0:
      echo "Attempting to read ", maxElements, " elements:"
      try:
        let unchecked = cast[ptr UncheckedArray[int]](p)
        for i in 0..<maxElements:
          echo &"  [{i}]: {unchecked[i]}"
      except:
        echo "  (Failed to read elements - invalid or synthetic address)"
    else:
      echo "  (Skipping read - NULL pointer)"
    
    echo "==============================="

template vmDebugMemoryOperation*(operation: string, src: untyped, dest: untyped, size: int) =
  ## Debug memory operations like memcpy/memmove
  static:
    echo "=== VM Memory Operation Debug ==="
    echo "Operation: ", operation
    echo "Source: 0x", cast[int](src).toHex
    echo "Dest: 0x", cast[int](dest).toHex
    echo "Size: ", size, " bytes"
    
    let srcAddr = cast[int](src)
    let destAddr = cast[int](dest)
    
    if srcAddr >= 1 and srcAddr <= 1000:
      echo "Source Type: Synthetic address"
    elif srcAddr == 0:
      echo "Source Type: NULL"
    else:
      echo "Source Type: Real address"
    
    if destAddr >= 1 and destAddr <= 1000:
      echo "Dest Type: Synthetic address"
    elif destAddr == 0:
      echo "Dest Type: NULL"
    else:
      echo "Dest Type: Real address"
    
    # Check for overlap
    if destAddr < srcAddr + size and srcAddr < destAddr + size:
      echo "Memory Overlap: YES (requires careful copy direction)"
      if destAddr < srcAddr:
        echo "Copy Direction: Forward (dest < src)"
      else:
        echo "Copy Direction: Backward (dest > src)"
    else:
      echo "Memory Overlap: NO (simple forward copy)"
    
    echo "================================="

template vmDebugYamlRepr*(node: untyped) =
  ## Generate a YAML-like representation of a node's structure
  static:
    echo "=== VM YAML Node Representation ==="
    echo "node:"
    echo "  type: ", $typeof(node)
    echo "  address: 0x", cast[int](unsafeAddr node).toHex
    echo "  value: ", repr(node)
    
    # Try to show additional structure for complex types
    when node is array:
      echo "  array_info:"
      echo "    length: ", node.len
      echo "    element_type: ", $typeof(node[0])
      echo "    elements:"
      for i in 0..<min(node.len, 5):
        echo &"      - index: {i}"
        echo &"        value: {node[i]}"
        echo &"        address: 0x{cast[int](unsafeAddr node[i]).toHex}"
      if node.len > 5:
        echo &"    # ... and {node.len - 5} more elements"
    elif node is ptr:
      echo "  pointer_info:"
      echo "    target_address: 0x", cast[int](node).toHex
      let address = cast[int](node)
      if address >= 1 and address <= 1000:
        echo "    address_type: synthetic"
        echo "    likely_array_index: ", address - 1
      elif address == 0:
        echo "    address_type: null"
      else:
        echo "    address_type: real"
    
    echo "===================================="

template vmDebugContextInfo*() =
  ## Show information about the current VM execution context
  static:
    echo "=== VM Context Information ==="
    echo "Compilation Mode: Static evaluation"
    echo "Debug Build: Enabled"
    echo "VM Context: Active"
    echo "=============================="

# Convenience macro for conditional debugging
template vmDebugWhen*(condition: bool, body: untyped) =
  ## Execute debugging code only when condition is true
  static:
    if condition:
      body

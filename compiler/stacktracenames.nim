## Module for storing custom stack trace names and reraise modes

import std/tables

# Global table to store custom stack trace names
var stackTraceNameTable {.global.}: Table[int, string]

# Global table to store reraise modes
var reraiseModeTable {.global.}: Table[int, string]
var reraiseModeNameTable {.global.}: Table[int, string]  # symId -> proc name

proc storeStackTraceName*(symId: int, name: string) =
  ## Store a custom stack trace name for a symbol
  stackTraceNameTable[symId] = name

proc getStackTraceName*(symId: int): string =
  ## Get a custom stack trace name for a symbol, returns empty string if not found
  if symId in stackTraceNameTable:
    return stackTraceNameTable[symId]
  return ""

proc hasStackTraceName*(symId: int): bool =
  ## Check if a symbol has a custom stack trace name
  symId in stackTraceNameTable

proc storeReraiseMode*(symId: int, mode: string, procName: string = "") =
  ## Store a reraise mode for a symbol
  reraiseModeTable[symId] = mode
  if procName != "":
    reraiseModeNameTable[symId] = procName

proc getReraiseMode*(symId: int): string =
  ## Get a reraise mode for a symbol, returns empty string if not found
  if symId in reraiseModeTable:
    return reraiseModeTable[symId]
  return ""

proc hasReraiseMode*(symId: int): bool =
  ## Check if a symbol has a custom reraise mode
  symId in reraiseModeTable

proc getReraiseModeProcName*(symId: int): string =
  ## Get the procedure name for a symbol with reraise mode
  if symId in reraiseModeNameTable:
    return reraiseModeNameTable[symId]
  return ""

proc getAllReraiseModes*(): seq[(string, string)] =
  ## Get all reraise modes as (procName, mode) pairs
  result = @[]
  for symId, mode in reraiseModeTable.pairs:
    let procName = getReraiseModeProcName(symId)
    if procName != "":
      result.add((procName, mode))

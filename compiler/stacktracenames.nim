## Module for storing custom stack trace names and reraise modes

import std/tables

# Global table to store custom stack trace names
var stackTraceNameTable {.global.}: Table[int, string]

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

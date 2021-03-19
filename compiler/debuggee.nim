# This is a debug aid to ease setting conditional breakpoints.

from std/os import splitFile, getEnv
from std/strutils import parseInt

var debuggeeTarget* = getEnv("NIM_DEBUGGEE")
var debuggeeTargetLine* = getEnv("NIM_DEBUGGEE_LINE", "1").parseInt()
var debuggeeTargetColumn* = getEnv("NIM_DEBUGGEE_COLUMN", "0").parseInt()
var debuggee*: string
var debuggeeLine*: int
var debuggeeColumn*: int
var debugger_isCompilingDebuggeeTarget* {.exportc.}: bool

#[ proc debugger_isCompilingDebuggeeTarget(): bool {.exportc.} =
  isCompilingDebuggeeTarget ]#

template setDebuggeeTarget*(s: string) =
  when compileOption("debugger"):
    debuggeeTarget = s

template setDebuggee*(s: string) =
  when compileOption("debugger"):
    debuggee = s

template setDebuggeeLineInfo*(line, column: SomeInteger | int16) = # TODO: why isn't `int16` a `SomeInteger`?
  when compileOption("debugger"):
    debuggeeLine = line.int
    debuggeeColumn = column.int
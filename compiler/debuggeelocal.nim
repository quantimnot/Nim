# This is a debug aid to ease setting conditional breakpoints.
from debuggee as dbg import setDebuggeeLineInfo, setDebuggee
export setDebuggeeLineInfo, setDebuggee

var debuggeeTarget* {.extern: "debuggeeTarget".} = addr(dbg.debuggeeTarget)
var debuggee* {.extern: "debuggee".} = addr(dbg.debuggee)
var debuggeeLine* {.extern: "debuggeeLine".} = addr(dbg.debuggeeLine)
var debuggeeColumn* {.extern: "debuggeeColumn".} = addr(dbg.debuggeeColumn)
var isCompilingDebuggeeTarget* {.extern: "isCompilingDebuggeeTarget".} = addr(dbg.debugger_isCompilingDebuggeeTarget)
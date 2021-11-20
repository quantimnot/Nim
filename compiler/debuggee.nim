# This is a debug aid to ease setting conditional breakpoints.

when compileOption("debugger"):
  from std/os import splitFile, getEnv
  from std/strutils import parseInt
  from std/posix import `raise`, SIGTRAP, signal
  var debuggeeTarget* = getEnv("NIM_DEBUGGEE")
    # module name that we want to debug the compilation of
  var debuggeeTargetLine* = getEnv("NIM_DEBUGGEE_LINE", "1").parseInt()
    # module line that we want to debug the compilation of
  var debuggeeTargetColumn* = getEnv("NIM_DEBUGGEE_COLUMN", "0").parseInt()
    # module column that we want to debug the compilation of
  var debuggee*: string
    # module name that is currently being compiled
  var debuggeeLine*: int
    # module line that is currently being compiled
  var debuggeeColumn*: int
    # module column that is currently being compiled
  var debugger_isCompilingDebuggeeTarget* {.exportc.}: bool
    # used by the debugger for conditional expressions

  proc onSigTrap(a: cint) {.exportc, noconv.} = discard
    # A dummy SIGTRAP handler.
    # It is called when a SIGTRAP is raised.
    # SIGTRAP is raised when code of interest is being compiled.
    # The debugger sets a breakpoint on this and then runs commands like
    # enabling all other breakpoints.
    # SEE ALSO
    #   * `compiler.lldb`
    #   * `setDebuggeeLineInfo`

  # install the SIGTRAP handler
  signal(SIGTRAP, onSigTrap)

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
    if debuggee == debuggeeTarget and debuggeeLine == debuggeeTargetLine:
      debugger_isCompilingDebuggeeTarget = true
      discard `raise`(SIGTRAP)
    else:
      debugger_isCompilingDebuggeeTarget = false

discard """
"""

import std/[macros, strutils]

# Inline .warning's

macro warningIsNotLastChild: untyped =
  quote do:
    {.warning: "I warned you!".} #[tt.Warning
             ^ I warned you! [User]]#
    discard ""
warningIsNotLastChild()

macro warningIsLastChild: untyped =
  quote do:
    {.warning: "I warned you!".} #[tt.Warning
             ^ I warned you! [User]]#
warningIsLastChild()

macro warningIsLastChildCallsite: untyped {.callsite.} =
  quote do:
    {.warning: "I warned you!".}
warningIsLastChildCallsite() #[tt.Warning
                          ^ I warned you! [User]]#

# Old Nim behaviour

macro oldNimBehavior: untyped =
  # The old behavior was to only change the last line of a template or macro
  # stmtlist. That led to incorrect stack traces.
  quote do:
    raise newException(ValueError, "Exception raised inside quote block")
    discard "Error showed at exception line, but only if this line exists."
try: oldNimBehavior()
except ValueError as e: doAssert e.getStackTrace.contains("tquote_lineinfo.nim(33)"), e.getStackTrace

macro singleStatement: untyped =
  quote do:
    raise (ref ValueError)(msg: "Exception raised inside quote block", parent: nil)
try: singleStatement()
except ValueError as e: doAssert e.getStackTrace.contains("tquote_lineinfo.nim(40)"), e.getStackTrace

# Macro .callsite support

macro oldNimBehaviorCallsite: untyped {.callsite.} =
  quote do:
    raise newException(ValueError, "Exception raised inside quote block")
    discard "Error showed at exception line, but only if this line exists."
try: oldNimBehaviorCallsite()
except ValueError as e: doAssert e.getStackTrace.contains("tquote_lineinfo.nim(50)"), e.getStackTrace

macro singleStatementCallsite: untyped {.callsite.} =
  quote do:
    raise (ref ValueError)(msg: "Exception raised inside quote block", parent: nil)
try: singleStatementCallsite()
except ValueError as e: doAssert e.getStackTrace.contains("tquote_lineinfo.nim(56)"), e.getStackTrace

# Template support

template oldNimBehaviorTemplate: untyped =
  raise newException(ValueError, "Exception raised inside quote block")
  discard "Error showed at exception line, but only if this line exists."
try: oldNimBehaviorTemplate()
except ValueError as e: doAssert e.getStackTrace.contains("tquote_lineinfo.nim(62)"), e.getStackTrace

template singleStatementTemplate: untyped =
  raise (ref ValueError)(msg: "Exception raised inside quote block", parent: nil)
try: singleStatementTemplate()
except ValueError as e: doAssert e.getStackTrace.contains("tquote_lineinfo.nim(68)"), e.getStackTrace

template singleStatementCallsiteTemplate: untyped {.callsite.} =
  raise (ref ValueError)(msg: "Exception raised inside quote block", parent: nil)
try: singleStatementCallsiteTemplate()
except ValueError as e: doAssert e.getStackTrace.contains("tquote_lineinfo.nim(74)"), e.getStackTrace

template oldNimBehaviorTemplateCallsite: untyped {.callsite.} =
  raise newException(ValueError, "Exception raised inside quote block")
  discard "Error showed at exception line, but only if this line exists."
try: oldNimBehaviorTemplateCallsite()
except ValueError as e: doAssert e.getStackTrace.contains("tquote_lineinfo.nim(80)"), e.getStackTrace

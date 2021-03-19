## =======================
## Native Debugger Support
## =======================
##
## Some aids for debugging Nim projects with a native debugger.
##
##
## Design
## ======
##
## Debuggers
## =========
##
## LLDB
## ----
##
##
##
## GDB
## ---
##
##
##
## See also
## --------
##
##
##
## TODO
## ----
##
## *
## *
## *
##


proc debuggerInit {.exportc.} =
  echo "Nim Debugger Runtime ENABLED"
proc debuggerRepr(kind: cstring, address: pointer): cstring {.exportc.} =
  kind
proc debuggerHint(kind: cstring): cstring {.exportc.} =
  kind

const debuggerSection = """
__asm__ (
  ".pushsection __TEXT, debugger\n"
  ".byte 4\n" // python text
  ".byte 0\n"
  ".popsection\n"
);
"""

{.emit: debuggerSection.}

from ast import PNode, safeLen
from renderer import renderTree

proc debuggerRenderTree(node: PNode): string {.exportc.} =
  renderTree node

func debuggerNodeSonsLen(node: PNode): int {.exportc.} =
  safeLen node
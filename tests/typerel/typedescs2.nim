discard """
  errormsg: "invalid type: 'typedesc[Table]' [1] for const [2]"
  file: "typedescs2.nim"
  line: 16
"""

# bug #9961

import typetraits
import tables

proc test(v: typedesc) =
  echo v.type.name

# This crashes the compiler
const b: typedesc = Table
test b

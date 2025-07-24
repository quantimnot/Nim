discard """
  errormsg: "invalid type: 'empty' [1] in this context: 'array[0..0, (string, seq[empty])]' [2] for var"
  line: 8
"""

# bug #3948

var headers=[("headers", @[])]

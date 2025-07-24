discard """
errormsg: "invalid type: 'SomeNumber' [1] in this context: 'seq[SomeNumber]' [2] for var"
line: 6
"""

var seqwat: seq[SomeNumber] = @[]

proc foo(x: SomeNumber) =
  seqwat.add(x)
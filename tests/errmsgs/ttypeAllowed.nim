discard """
cmd: "nim check $file"
errormsg: ""
nimout: '''
ttypeAllowed.nim(13, 5) Error: invalid type: 'iterator (a: int, b: int, step: Positive): int{.inline, noSideEffect, gcsafe.}' [1] for let [2]
ttypeAllowed.nim(17, 7) Error: invalid type: 'iterator (a: int, b: int, step: Positive): int{.inline, noSideEffect, gcsafe.}' [1] for const [2]
ttypeAllowed.nim(21, 5) Error: invalid type: 'iterator (a: int, b: int, step: Positive): int{.inline, noSideEffect, gcsafe.}' [1] for var [2]
ttypeAllowed.nim(26, 10) Error: invalid type: 'iterator (a: int, b: int, step: Positive): int{.inline, noSideEffect, gcsafe.}' [1] for result [2]
'''
"""


let f1 = case true
  of true:  countup[int]
  of false: countdown[int]

const f2 = case true
  of true:  countup[int]
  of false: countdown[int]

var f3 = case true
  of true:  countup[int]
  of false: countdown[int]

proc foobar(): auto =
  result = case true
    of true:  countup[int]
    of false: countdown[int]

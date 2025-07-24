discard """
cmd: "nim check $file"
errormsg: "invalid type: 'typedesc[int]' [1] in this context: 'array[0..0, typedesc[int]]' [2] for var"
nimout: '''
t9932.nim(10, 5) Error: invalid type: 'type' [1] in this context: 'array[0..0, type]' [2] for var
t9932.nim(11, 5) Error: invalid type: 'typedesc[int]' [1] in this context: 'array[0..0, typedesc[int]]' [2] for var
'''
"""

var y: array[1,type]
var x = [int]

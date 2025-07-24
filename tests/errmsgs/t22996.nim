discard """
  errormsg: "invalid type: 'typedesc[string]' [1] for const [2]"
"""

# bug #22996
type MyObject = ref object
  _ = string

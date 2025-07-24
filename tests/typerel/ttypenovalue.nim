discard """
  errormsg: "invalid type: 'typedesc[seq[tuple[title: string, body: string]]]' [1] for var [2]"
  line: 7
"""

proc crashAndBurn() =
  var stuff = seq[tuple[title, body: string]]


crashAndBurn()

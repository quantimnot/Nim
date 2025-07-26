## Runtime support for reraiseMode pragma

# Simple storage for reraise modes without GC dependencies
# Fixed-size arrays to avoid seq (which is GC-managed)
const MaxReraiseEntries = 128

type
  ReraiseEntry = object
    procName: array[64, char]  # Fixed-size char array instead of string
    mode: array[16, char]      # Fixed-size char array for mode
    used: bool                 # Whether this entry is in use

# Global storage for reraise modes (fixed array instead of seq)
var reraiseModeEntries {.threadvar.}: array[MaxReraiseEntries, ReraiseEntry]
var entryCount {.threadvar.}: int

proc copyStringToArray(src: string, dest: var array[64, char]) =
  ## Copy string to fixed char array
  for i in 0..<min(src.len, 63):
    dest[i] = src[i]
  dest[min(src.len, 63)] = '\0'  # Null terminate

proc copyStringToArray16(src: string, dest: var array[16, char]) =
  ## Copy string to fixed char array (16 chars)
  for i in 0..<min(src.len, 15):
    dest[i] = src[i]
  dest[min(src.len, 15)] = '\0'  # Null terminate

proc arraysEqual(a: array[64, char], s: string): bool =
  ## Compare char array with string
  var i = 0
  while i < s.len and i < 63 and a[i] != '\0':
    if a[i] != s[i]: return false
    inc i
  return i == s.len and (i == 63 or a[i] == '\0')

proc setReraiseMode*(procName: string, mode: string) =
  ## Set the reraise mode for a procedure
  # Check if entry already exists
  for i in 0..<MaxReraiseEntries:
    if reraiseModeEntries[i].used and arraysEqual(reraiseModeEntries[i].procName, procName):
      copyStringToArray16(mode, reraiseModeEntries[i].mode)
      return

  # Find empty slot and add new entry
  for i in 0..<MaxReraiseEntries:
    if not reraiseModeEntries[i].used:
      reraiseModeEntries[i].used = true
      copyStringToArray(procName, reraiseModeEntries[i].procName)
      copyStringToArray16(mode, reraiseModeEntries[i].mode)
      if i >= entryCount:
        entryCount = i + 1
      return

proc arrayToString(a: array[16, char]): string =
  ## Convert char array to string
  result = ""
  for i in 0..<16:
    if a[i] == '\0': break
    result.add a[i]

proc getReraiseMode*(procName: string): string =
  ## Get the reraise mode for a procedure, returns "verbose" (default) if not found
  for i in 0..<entryCount:
    if reraiseModeEntries[i].used and arraysEqual(reraiseModeEntries[i].procName, procName):
      return arrayToString(reraiseModeEntries[i].mode)
  return "verbose"  # default mode

proc hasCustomReraiseMode*(procName: string): bool =
  ## Check if a procedure has a custom reraise mode
  for i in 0..<entryCount:
    if reraiseModeEntries[i].used and arraysEqual(reraiseModeEntries[i].procName, procName):
      return true
  return false
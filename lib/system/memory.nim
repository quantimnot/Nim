{.push stack_trace: off.}

const useLibC = not defined(nimNoLibc) and not vm and not defined(js)

when useLibC:
  import ansi_c

proc nimCopyMem*(dest, source: pointer, size: Natural) {.nonReloadable, compilerproc, inline.} =
  when useLibC:
    c_memcpy(dest, source, cast[csize_t](size))
  elif defined(js):
    # JavaScript backend: arrays and indices are passed separately
    {.emit: """
    if (`size` > 0) {
      for (var i = 0; i < `size`; i++) {
        `dest`[`dest`_Idx + i] = `source`[`source`_Idx + i];
      }
    }
    """.}
  else:
    # let d = cast[ptr UncheckedArray[byte]](dest)
    # let s = cast[ptr UncheckedArray[byte]](source)
    # var i = 0
    # while i < size:
    #   d[i] = s[i]
    #   inc i
    var pd = dest
    var ps = source
    var i = 0
    while i < size:
      cast[ptr byte](pd)[] = cast[ptr byte](ps)[]
      pd = cast[pointer](cast[int](pd) + 1)
      ps = cast[pointer](cast[int](ps) + 1)
      inc i

proc nimMoveMem*(dest, source: pointer, size: Natural) {.nonReloadable, compilerproc, inline.} =
  when useLibC:
    c_memmove(dest, source, cast[csize_t](size))
  elif defined(js):
    # JavaScript backend: handle overlapping memory regions
    {.emit: """
    if (`size` > 0) {
      if (`dest` === `source` && `dest`_Idx > `source`_Idx && `dest`_Idx < `source`_Idx + `size`) {
        // Overlapping, copy backwards
        for (var i = `size` - 1; i >= 0; i--) {
          `dest`[`dest`_Idx + i] = `source`[`source`_Idx + i];
        }
      } else {
        // No overlap or safe to copy forward
        for (var i = 0; i < `size`; i++) {
          `dest`[`dest`_Idx + i] = `source`[`source`_Idx + i];
        }
      }
    }
    """.}
  else:
    {.cast(noSideEffect).}:
      var pd = dest
      var ps = source
      if cast[int](pd) < cast[int](ps) or
         cast[int](pd) >= cast[int](ps) + size:
        # No overlap or dest before source - copy forward
        var i = 0
        while i < size:
          cast[ptr byte](pd)[] = cast[ptr byte](ps)[]
          pd = cast[pointer](cast[int](pd) + 1)
          ps = cast[pointer](cast[int](ps) + 1)
          inc i
      else:
        # Overlap with dest after source - copy backward
        var i = size - 1
        while i >= 0:
          cast[ptr byte](pd)[] = cast[ptr byte](ps)[]
          pd = cast[pointer](cast[int](pd) - 1)
          ps = cast[pointer](cast[int](ps) - 1)
          dec i
      # let d = cast[ptr UncheckedArray[byte]](dest)
      # let s = cast[ptr UncheckedArray[byte]](source)
      
      # if cast[int](dest) < cast[int](source) or
      #    cast[int](dest) >= cast[int](source) + size:
      #   # No overlap or dest before source - copy forward
      #   var i = 0
      #   while i < size:
      #     d[i] = s[i]
      #     inc i
      # else:
      #   # Overlap with dest after source - copy backward
      #   var i = size
      #   while i > 0:
      #     dec i
      #     d[i] = s[i]

proc nimSetMem*(a: pointer, v: cint, size: Natural) {.nonReloadable, inline.} =
  when useLibC:
    c_memset(a, v, cast[csize_t](size))
  else:
    let a = cast[ptr UncheckedArray[byte]](a)
    var i = 0
    let v = cast[byte](v)
    while i < size:
      a[i] = v
      inc i

proc nimZeroMem*(p: pointer, size: Natural) {.compilerproc, nonReloadable, inline.} =
  nimSetMem(p, 0, size)

proc nimCmpMem*(a, b: pointer, size: Natural): cint {.compilerproc, nonReloadable, inline.} =
  when useLibC:
    c_memcmp(a, b, cast[csize_t](size))
  else:
    let a = cast[ptr UncheckedArray[byte]](a)
    let b = cast[ptr UncheckedArray[byte]](b)
    var i = 0
    while i < size:
      let d = a[i].cint - b[i].cint
      if d != 0: return d
      inc i

proc nimCStrLen*(a: cstring): int {.compilerproc, nonReloadable, inline.} =
  if a.isNil: return 0
  when useLibC:
    cast[int](c_strlen(a))
  else:
    var a = cast[ptr byte](a)
    while a[] != 0:
      a = cast[ptr byte](cast[uint](a) + 1)
      inc result

{.pop.}

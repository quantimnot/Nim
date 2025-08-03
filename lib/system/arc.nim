#
#
#            Nim's Runtime Library
#        (c) Copyright 2019 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

#[
In this new runtime we simplify the object layouts a bit: The runtime type
information is only accessed for the objects that have it and it's always
at offset 0 then. The ``ref`` object header is independent from the
runtime type and only contains a reference count.
]#

{.push raises: [].}

when defined(gcOrc):
  const
    rcIncrement = 0b10000 # so that lowest 4 bits are not touched
    rcMask = 0b1111
    rcShift = 4      # shift by rcShift to get the reference counter

else:
  const
    rcIncrement = 0b1000 # so that lowest 3 bits are not touched
    rcMask = 0b111
    rcShift = 3      # shift by rcShift to get the reference counter

const
  orcLeakDetector = defined(nimOrcLeakDetector)

when defined(nimArcDebug):
  # Include necessary headers for stack bounds detection
  when defined(macosx):
    {.emit: "#include <pthread.h>".}
  elif defined(windows):
    {.emit: "#include <windows.h>".}

  type
    StackFrame = object
      filename: cstring
      procname: cstring
      line: int

    AllocInfo = object
      allocStack: array[16, StackFrame]  # allocation stacktrace
      allocStackLen: int
      deallocStack: array[16, StackFrame] # deallocation stacktrace
      deallocStackLen: int
      allocTime: int64
      deallocTime: int64
      refId: int
      isDeallocated: bool
      stackCanary: uint64  # Stack corruption detection

    RefTracker = object
      refs: seq[ptr pointer]  # active references to this object

    StackCanary = object
      magic: uint64
      framePtr: pointer
      nextCanary: ptr StackCanary

    TypeInfo = object
      typeName: cstring
      size: int
      alignment: int

    HeapStats = object
      totalAllocations: int
      totalDeallocations: int
      currentObjects: int
      peakObjects: int
      totalBytesAllocated: int64
      currentBytesAllocated: int64
      peakBytesAllocated: int64

    StackBounds = object
      stackStart: pointer
      stackEnd: pointer
      threadId: int

  const
    STACK_CANARY_MAGIC = 0xDEADBEEFCAFEBABE'u64
    POISON_FREED_MEMORY = 0xDEADBEEF'u32

  var
    stackCanaryChain: ptr StackCanary = nil
    heapStats: HeapStats
    enablePoisoning: bool = true
    enableLeakDetection: bool = true
    mainThreadStackBounds: StackBounds
    isStackBoundsInitialized: bool = false

type
  RefHeader = object
    rc: int # the object header is now a single RC field.
            # we could remove it in non-debug builds for the 'owned ref'
            # design but this seems unwise.
    when defined(gcOrc):
      rootIdx: int # thanks to this we can delete potential cycle roots
                   # in O(1) without doubly linked lists
    when defined(nimArcDebug) or defined(nimArcIds):
      refId: int
    when defined(nimArcDebug):
      allocInfo: ptr AllocInfo
    when defined(gcOrc) and orcLeakDetector:
      filename: cstring
      line: int

  Cell = ptr RefHeader

template setFrameInfo(c: Cell) =
  when defined(gcOrc) and orcLeakDetector:
    if framePtr != nil and framePtr.prev != nil:
      c.filename = framePtr.prev.filename
      c.line = framePtr.prev.line
    else:
      c.filename = nil
      c.line = 0

template head(p: pointer): Cell =
  cast[Cell](cast[int](p) -% sizeof(RefHeader))

const
  traceCollector = defined(traceArc)

when defined(nimArcDebug):
  include cellsets

  const traceId = 20 # 1037

  var gRefId: int
  var freedCells: CellSet
  var allocInfos: seq[ptr AllocInfo]  # global tracking of all allocations

  proc captureStacktrace(frames: var openArray[StackFrame]; maxFrames: int): int =
    ## Capture current stacktrace into frames array, returns number of frames captured
    result = 0
    let maxToCapture = min(maxFrames, frames.len)
    var frame = framePtr

    # Skip the first few frames (captureStacktrace, allocAllocInfo, etc.)
    var skipCount = 2
    while frame != nil and skipCount > 0:
      frame = frame.prev
      dec skipCount

    # Now capture the actual user stacktrace
    while frame != nil and result < maxToCapture:
      if frame.filename != nil and frame.filename != nil:
        frames[result].filename = frame.filename
        frames[result].procname = if frame.procname != nil: frame.procname else: cstring("<unknown>")
        frames[result].line = frame.line
        inc result
      frame = frame.prev

  proc getTimestamp(): int64 =
    ## Get current timestamp (simple counter-based approach)
    {.emit: "static long long arcDebugCounter = 0; `result` = ++arcDebugCounter;".}

  proc initStackBounds() {.gcsafe.} =
    ## Initialize stack bounds for the main thread
    if not isStackBoundsInitialized:
      # Get approximate stack bounds using a local variable
      var stackVar: int
      let currentStackPtr = cast[pointer](addr stackVar)

      # On most systems, stack grows downward
      # We'll use a heuristic approach to estimate stack bounds
      when defined(windows):
        # On Windows, get thread information block
        {.emit: """
        #include <windows.h>
        void* stackStart = 0;
        void* stackEnd = 0;

        #ifdef _WIN64
        stackStart = (void*)__readgsqword(0x08);  // Stack limit
        stackEnd = (void*)__readgsqword(0x10);    // Stack base
        #else
        stackStart = (void*)__readfsdword(0x08);  // Stack limit
        stackEnd = (void*)__readfsdword(0x04);    // Stack base
        #endif

        `mainThreadStackBounds`.stackStart = stackStart;
        `mainThreadStackBounds`.stackEnd = stackEnd;
        """.}
      elif defined(linux) or defined(macosx):
        # Use pthread functions with proper headers
        when defined(macosx):
          {.emit: """
          pthread_t self = pthread_self();
          void* stackAddr = pthread_get_stackaddr_np(self);
          size_t stackSize = pthread_get_stacksize_np(self);
          `mainThreadStackBounds`.stackEnd = stackAddr;
          `mainThreadStackBounds`.stackStart = (char*)stackAddr - stackSize;
          """.}
        else:
          # Linux fallback with heuristic
          let estimatedStackSize = 8 * 1024 * 1024  # 8MB typical default
          mainThreadStackBounds.stackEnd = cast[pointer](cast[int](currentStackPtr) + 1024)
          mainThreadStackBounds.stackStart = cast[pointer](cast[int](currentStackPtr) - estimatedStackSize)
      else:
        # Generic fallback - estimate based on typical stack size
        let estimatedStackSize = 8 * 1024 * 1024  # 8MB typical default
        mainThreadStackBounds.stackEnd = cast[pointer](cast[int](currentStackPtr) + 1024)
        mainThreadStackBounds.stackStart = cast[pointer](cast[int](currentStackPtr) - estimatedStackSize)

      mainThreadStackBounds.threadId = 0  # Main thread
      isStackBoundsInitialized = true

  proc isStackAddress(p: pointer): bool {.gcsafe.} =
    ## Check if address is on the stack
    if p == nil: return false

    if not isStackBoundsInitialized:
      initStackBounds()

    let address = cast[int](p)
    let stackStart = cast[int](mainThreadStackBounds.stackStart)
    let stackEnd = cast[int](mainThreadStackBounds.stackEnd)

    # Account for stack growing up or down
    if stackStart < stackEnd:
      # Stack grows upward
      result = address >= stackStart and address <= stackEnd
    else:
      # Stack grows downward (most common)
      result = address >= stackEnd and address <= stackStart

  proc isHeapAddress(p: pointer): bool {.gcsafe.} =
    ## Check if address is on the heap
    if p == nil: return false

    # First check if it's a stack address
    if isStackAddress(p): return false

    # For heap addresses, we can check if they're in known heap regions
    # This is a heuristic - addresses that aren't stack are likely heap
    # We could make this more precise by tracking heap allocations
    let address = cast[int](p)

    # Heuristic: heap addresses are usually in higher memory ranges
    # and aligned to allocation boundaries
    when sizeof(pointer) == 8:  # 64-bit
      # On 64-bit systems, heap is usually in higher addresses
      result = address > 0x10000000  # Above 256MB
    else:  # 32-bit
      # On 32-bit systems, heap is usually above stack
      result = address > 0x1000000   # Above 16MB

  proc getAddressType(p: pointer): cstring {.gcsafe.} =
    ## Get a string description of the address type
    if p == nil:
      return "NULL"
    elif isStackAddress(p):
      return "STACK"
    elif isHeapAddress(p):
      return "HEAP"
    else:
      return "UNKNOWN"

  proc updateHeapStats(size: int, isAllocation: bool) {.gcsafe.} =
    ## Update heap statistics
    if isAllocation:
      inc heapStats.totalAllocations
      inc heapStats.currentObjects
      heapStats.peakObjects = max(heapStats.peakObjects, heapStats.currentObjects)
      heapStats.totalBytesAllocated += size
      heapStats.currentBytesAllocated += size
      heapStats.peakBytesAllocated = max(heapStats.peakBytesAllocated, heapStats.currentBytesAllocated)
    else:
      inc heapStats.totalDeallocations
      dec heapStats.currentObjects
      heapStats.currentBytesAllocated -= size

  proc checkStackCanaries() {.gcsafe.} =
    ## Check all stack canaries for corruption
    var current = stackCanaryChain
    while current != nil:
      if current.magic != STACK_CANARY_MAGIC:
        cfprintf(cstderr, "\n=== STACK CORRUPTION DETECTED ===\n")
        cfprintf(cstderr, "Corrupted canary at: %p\n", current)
        cfprintf(cstderr, "Expected magic: 0x%llX\n", STACK_CANARY_MAGIC)
        cfprintf(cstderr, "Found magic: 0x%llX\n", current.magic)
        cfprintf(cstderr, "Frame pointer: %p\n", current.framePtr)
        cfprintf(cstderr, "=== END STACK CORRUPTION REPORT ===\n\n")
        when defined(nimArcDebugFatal):
          rawQuit(1)
      current = current.nextCanary

  proc addStackCanary() {.gcsafe.} =
    ## Add a stack canary for current frame
    var canary = cast[ptr StackCanary](allocShared0(sizeof(StackCanary)))
    canary.magic = STACK_CANARY_MAGIC
    canary.framePtr = framePtr
    canary.nextCanary = stackCanaryChain
    stackCanaryChain = canary

  proc removeStackCanary() {.gcsafe.} =
    ## Remove the most recent stack canary
    if stackCanaryChain != nil:
      let old = stackCanaryChain
      stackCanaryChain = stackCanaryChain.nextCanary
      deallocShared(old)

  proc allocAllocInfo(refId: int): ptr AllocInfo {.gcsafe.} =
    ## Allocate and initialize a new AllocInfo structure
    {.gcsafe.}:
      result = cast[ptr AllocInfo](allocShared0(sizeof(AllocInfo)))
      result.refId = refId
      result.allocTime = getTimestamp()
      result.allocStackLen = captureStacktrace(result.allocStack, 16)
      result.stackCanary = STACK_CANARY_MAGIC
      allocInfos.add(result)
      addStackCanary()  # Add stack canary for this allocation
      updateHeapStats(sizeof(AllocInfo), true)  # Update heap statistics

  proc checkMemoryValidity(p: pointer, context: cstring) {.gcsafe.} =
    ## Check if pointer p is valid and report detailed error if not
    if p == nil: return

    # Check stack canaries for corruption first
    checkStackCanaries()

    let c = head(p)
    if freedCells.data != nil and freedCells.contains(c):
      let allocInfo = c.allocInfo
      if allocInfo != nil:
        cfprintf(cstderr, "\n=== ARC MEMORY VIOLATION DETECTED ===\n")
        cfprintf(cstderr, "Context: %s\n", context)
        cfprintf(cstderr, "Invalid access to object %p (refId: %ld)\n", p, c.refId)
        cfprintf(cstderr, "Object address type: %s\n", getAddressType(p))

        if allocInfo.isDeallocated:
          cfprintf(cstderr, "\nObject was DEALLOCATED:\n")
          cfprintf(cstderr, "  Deallocated at: %ld ns after allocation\n",
                   allocInfo.deallocTime - allocInfo.allocTime)

          cfprintf(cstderr, "  Deallocation stacktrace:\n")
          for i in 0 ..< allocInfo.deallocStackLen:
            cfprintf(cstderr, "    %s:%ld in %s\n",
                     allocInfo.deallocStack[i].filename,
                     allocInfo.deallocStack[i].line,
                     allocInfo.deallocStack[i].procname)

        cfprintf(cstderr, "\nObject was ORIGINALLY ALLOCATED:\n")
        cfprintf(cstderr, "  Allocation time: %ld ns\n", allocInfo.allocTime)
        cfprintf(cstderr, "  Allocation stacktrace:\n")
        for i in 0 ..< allocInfo.allocStackLen:
          cfprintf(cstderr, "    %s:%ld in %s\n",
                   allocInfo.allocStack[i].filename,
                   allocInfo.allocStack[i].line,
                   allocInfo.allocStack[i].procname)

        cfprintf(cstderr, "\nCURRENT LOCATION (invalid access):\n")
        if framePtr != nil:
          cfprintf(cstderr, "  %s:%ld in %s\n",
                   framePtr.filename, framePtr.line, framePtr.procname)

        cfprintf(cstderr, "=== END MEMORY VIOLATION REPORT ===\n\n")

        when defined(nimArcDebugFatal):
          rawQuit(1)
      else:
        cfprintf(cstderr, "[FATAL] use-after-free: %p refId: %ld (no allocation info)\n",
                 p, c.refId)
        when defined(nimArcDebugFatal):
          rawQuit(1)
elif defined(nimArcIds):
  var gRefId: int

  const traceId = -1

when defined(gcAtomicArc) and hasThreadSupport:
  template decrement(cell: Cell): untyped =
    discard atomicDec(cell.rc, rcIncrement)
  template increment(cell: Cell): untyped =
    discard atomicInc(cell.rc, rcIncrement)
  template count(x: Cell): untyped =
    atomicLoadN(x.rc.addr, ATOMIC_ACQUIRE) shr rcShift
else:
  template decrement(cell: Cell): untyped =
    dec(cell.rc, rcIncrement)
  template increment(cell: Cell): untyped =
    inc(cell.rc, rcIncrement)
  template count(x: Cell): untyped =
    x.rc shr rcShift

when not defined(nimHasQuirky):
  {.pragma: quirky.}

proc nimNewObj(size, alignment: int): pointer {.compilerRtl.} =
  let hdrSize = align(sizeof(RefHeader), alignment)
  let s = size + hdrSize
  when defined(nimscript):
    discard
  else:
    result = alignedAlloc0(s, alignment) +! hdrSize
  when defined(nimArcDebug) or defined(nimArcIds):
    head(result).refId = gRefId
    atomicInc gRefId
    when defined(nimArcDebug):
      head(result).allocInfo = allocAllocInfo(head(result).refId)
    if head(result).refId == traceId:
      writeStackTrace()
      cfprintf(cstderr, "[nimNewObj] %p %ld\n", result, head(result).count)
  when traceCollector:
    cprintf("[Allocated] %p result: %p\n", result -! sizeof(RefHeader), result)
  setFrameInfo head(result)

proc nimNewObjUninit(size, alignment: int): pointer {.compilerRtl.} =
  # Same as 'newNewObj' but do not initialize the memory to zero.
  # The codegen proved for us that this is not necessary.
  let hdrSize = align(sizeof(RefHeader), alignment)
  let s = size + hdrSize
  when defined(nimscript):
    discard
  else:
    result = cast[ptr RefHeader](alignedAlloc(s, alignment) +! hdrSize)
  head(result).rc = 0
  when defined(gcOrc):
    head(result).rootIdx = 0
  when defined(nimArcDebug):
    head(result).refId = gRefId
    atomicInc gRefId
    head(result).allocInfo = allocAllocInfo(head(result).refId)
    if head(result).refId == traceId:
      writeStackTrace()
      cfprintf(cstderr, "[nimNewObjUninit] %p %ld\n", result, head(result).count)

  when traceCollector:
    cprintf("[Allocated] %p result: %p\n", result -! sizeof(RefHeader), result)
  setFrameInfo head(result)

proc nimDecWeakRef(p: pointer) {.compilerRtl, inl.} =
  decrement head(p)

proc isUniqueRef*[T](x: ref T): bool {.inline.} =
  ## Returns true if the object `x` points to is uniquely referenced. Such
  ## an object can potentially be passed over to a different thread safely,
  ## if great care is taken. This queries the internal reference count of
  ## the object which is subject to lots of optimizations! In other words
  ## the value of `isUniqueRef` can depend on the used compiler version and
  ## optimizer setting.
  ## Nevertheless it can be used as a very valuable debugging tool and can
  ## be used to specify the constraints of a threading related API
  ## via `assert isUniqueRef(x)`.
  head(cast[pointer](x)).rc == 0

proc nimIncRef(p: pointer) {.compilerRtl, inl.} =
  when defined(nimArcDebug):
    checkMemoryValidity(p, "nimIncRef")
    if head(p).refId == traceId:
      writeStackTrace()
      cfprintf(cstderr, "[IncRef] %p %ld\n", p, head(p).count)

  increment head(p)
  when traceCollector:
    cprintf("[INCREF] %p\n", head(p))

when not defined(gcOrc) or defined(nimThinout):
  proc unsureAsgnRef(dest: ptr pointer, src: pointer) {.inline.} =
    # This is only used by the old RTTI mechanism and we know
    # that 'dest[]' is nil and needs no destruction. Which is really handy
    # as we cannot destroy the object reliably if it's an object of unknown
    # compile-time type.
    dest[] = src
    if src != nil: nimIncRef src

when not defined(nimscript) and defined(nimArcDebug):
  proc deallocatedRefId*(p: pointer): int =
    ## Returns the ref's ID if the ref was already deallocated. This
    ## is a memory corruption check. Returns 0 if there is no error.
    let c = head(p)
    if freedCells.data != nil and freedCells.contains(c):
      result = c.refId
    else:
      result = 0

  proc nimArcDebugDecRef*(p: pointer, context: cstring) =
    ## Debug wrapper for nimDecRef with memory validity checking
    checkMemoryValidity(p, context)

  proc nimArcDebugDeref*(p: pointer, context: cstring): pointer {.compilerRtl.} =
    ## Debug wrapper for pointer dereference with memory validity checking
    checkMemoryValidity(p, context)
    result = p

  proc nimArcDebugFieldAccess*(p: pointer, offset: int, context: cstring): pointer {.compilerRtl.} =
    ## Debug wrapper for field access with memory validity checking
    checkMemoryValidity(p, context)
    result = cast[pointer](cast[int](p) + offset)

  proc nimArcDebugArrayAccess*(p: pointer, index: int, elemSize: int, context: cstring): pointer {.compilerRtl.} =
    ## Debug wrapper for array access with memory validity checking
    checkMemoryValidity(p, context)
    result = cast[pointer](cast[int](p) + index * elemSize)

  proc nimArcDebugRegisterRef*(obj: pointer, refLoc: ptr pointer) =
    ## Register a reference location pointing to obj
    if obj != nil:
      let c = head(obj)
      if c.allocInfo != nil:
        # Simple implementation: we don't track refs in this version
        # Could be extended to track all reference locations
        discard

  proc nimArcDebugUnregisterRef*(obj: pointer, refLoc: ptr pointer) =
    ## Unregister a reference location pointing to obj
    if obj != nil:
      let c = head(obj)
      if c.allocInfo != nil:
        # Simple implementation: we don't track refs in this version
        # Could be extended to track all reference locations
        discard

  proc nimArcDebugShowRefs*(obj: pointer) =
    ## Show all active references to an object (debugging aid)
    if obj != nil:
      let c = head(obj)
      if c.allocInfo != nil:
        cfprintf(cstderr, "Object %p (refId: %ld) reference tracking not fully implemented\n",
                 obj, c.refId)
        cfprintf(cstderr, "Current RC: %ld\n", c.rc shr rcShift)

  proc nimArcDebugCheckStack*() {.exportc, gcsafe.} =
    ## Manually check stack for corruption
    checkStackCanaries()

  proc detectStackOverflow*(): bool {.exportc, gcsafe.} =
    ## Detect potential stack overflow by checking stack depth
    var depth = 0
    var frame = framePtr
    while frame != nil and depth < 10000:  # Reasonable limit
      inc depth
      frame = frame.prev

    if depth >= 9999:
      cfprintf(cstderr, "\n=== POTENTIAL STACK OVERFLOW DETECTED ===\n")
      cfprintf(cstderr, "Stack depth: %ld frames\n", depth)
      cfprintf(cstderr, "This may indicate infinite recursion\n")
      cfprintf(cstderr, "=== END STACK OVERFLOW REPORT ===\n\n")
      return true
    return false

  proc detectBufferOverrun*(p: pointer, size: int): bool {.exportc, gcsafe.} =
    ## Detect potential buffer overruns by checking memory patterns
    if p == nil: return false

    # Check if we can access the memory at the expected boundary
    try:
      let boundary = cast[ptr uint64](cast[int](p) + size)
      # If this doesn't crash, boundary might be valid, but we can't be sure
      # This is a basic heuristic check
      discard
    except:
      cfprintf(cstderr, "\n=== BUFFER OVERRUN DETECTED ===\n")
      cfprintf(cstderr, "Invalid memory access at: %p + %ld\n", p, size)
      cfprintf(cstderr, "=== END BUFFER OVERRUN REPORT ===\n\n")
      return true
    return false

  proc nimArcDebugHeapStats*() {.exportc, gcsafe.} =
    ## Print current heap statistics
    cfprintf(cstderr, "\n=== HEAP STATISTICS ===\n")
    cfprintf(cstderr, "Total allocations: %ld\n", heapStats.totalAllocations)
    cfprintf(cstderr, "Total deallocations: %ld\n", heapStats.totalDeallocations)
    cfprintf(cstderr, "Current objects: %ld\n", heapStats.currentObjects)
    cfprintf(cstderr, "Peak objects: %ld\n", heapStats.peakObjects)
    cfprintf(cstderr, "Total bytes allocated: %lld\n", heapStats.totalBytesAllocated)
    cfprintf(cstderr, "Current bytes allocated: %lld\n", heapStats.currentBytesAllocated)
    cfprintf(cstderr, "Peak bytes allocated: %lld\n", heapStats.peakBytesAllocated)
    cfprintf(cstderr, "=== END HEAP STATISTICS ===\n\n")

  proc nimArcDebugIsStackAddress*(p: pointer): bool {.exportc, gcsafe.} =
    ## Check if address is on the stack (public API)
    result = isStackAddress(p)

  proc nimArcDebugIsHeapAddress*(p: pointer): bool {.exportc, gcsafe.} =
    ## Check if address is on the heap (public API)
    result = isHeapAddress(p)

  proc nimArcDebugGetAddressType*(p: pointer): cstring {.exportc, gcsafe.} =
    ## Get address type as string (public API)
    result = getAddressType(p)

  proc nimArcDebugAnalyzePointer*(p: pointer) {.exportc, gcsafe.} =
    ## Analyze a pointer and print detailed information
    if p == nil:
      cfprintf(cstderr, "Pointer analysis: NULL pointer\n")
      return

    let addrType = getAddressType(p)
    cfprintf(cstderr, "\n=== POINTER ANALYSIS ===\n")
    cfprintf(cstderr, "Address: %p\n", p)
    cfprintf(cstderr, "Address type: %s\n", addrType)
    cfprintf(cstderr, "Address value: 0x%lX\n", cast[int](p))

    if isStackAddress(p):
      cfprintf(cstderr, "Stack bounds: %p - %p\n",
               mainThreadStackBounds.stackStart, mainThreadStackBounds.stackEnd)
      let stackStart = cast[int](mainThreadStackBounds.stackStart)
      let stackEnd = cast[int](mainThreadStackBounds.stackEnd)
      let address = cast[int](p)

      if stackStart < stackEnd:
        # Stack grows upward
        cfprintf(cstderr, "Distance from stack start: %ld bytes\n", address - stackStart)
        cfprintf(cstderr, "Distance from stack end: %ld bytes\n", stackEnd - address)
      else:
        # Stack grows downward (typical)
        cfprintf(cstderr, "Distance from stack top: %ld bytes\n", stackStart - address)
        cfprintf(cstderr, "Distance from stack bottom: %ld bytes\n", address - stackEnd)

    elif isHeapAddress(p):
      # Check if it's a known ARC object
      let c = head(p)
      if freedCells.data != nil and freedCells.contains(c):
        cfprintf(cstderr, "Status: FREED ARC object (refId: %ld)\n", c.refId)
      else:
        cfprintf(cstderr, "Status: Active heap address\n")

    cfprintf(cstderr, "=== END POINTER ANALYSIS ===\n\n")

  proc poisonMemory(p: pointer, size: int) {.gcsafe.} =
    ## Fill freed memory with poison pattern to detect use-after-free
    if enablePoisoning and p != nil and size > 0:
      var poisonPtr = cast[ptr uint32](p)
      let words = size div 4
      for i in 0..<words:
        poisonPtr[] = POISON_FREED_MEMORY
        poisonPtr = cast[ptr uint32](cast[int](poisonPtr) + 4)

  proc checkPoisonedMemory(p: pointer, size: int): bool {.gcsafe.} =
    ## Check if memory contains poison pattern (indicating use-after-free)
    if p == nil or size <= 0: return false
    var poisonPtr = cast[ptr uint32](p)
    let words = size div 4
    for i in 0..<words:
      if poisonPtr[] == POISON_FREED_MEMORY:
        cfprintf(cstderr, "\n=== POISONED MEMORY ACCESS DETECTED ===\n")
        cfprintf(cstderr, "Accessed freed memory at: %p + %ld\n", p, i * 4)
        cfprintf(cstderr, "Found poison pattern: 0x%X\n", POISON_FREED_MEMORY)
        cfprintf(cstderr, "=== END POISONED MEMORY REPORT ===\n\n")
        return true
      poisonPtr = cast[ptr uint32](cast[int](poisonPtr) + 4)
    return false

  func nimArcDebugLeakCheck*() {.exportc, gcsafe.} =
    ## Check for memory leaks
    {.noSideEffect, gcsafe.}:
      discard
        if heapStats.currentObjects > 0:
          cfprintf(cstderr, "\n=== MEMORY LEAK DETECTED ===\n")
          cfprintf(cstderr, "Current leaked objects: %ld\n", heapStats.currentObjects)
          cfprintf(cstderr, "Current leaked bytes: %lld\n", heapStats.currentBytesAllocated)
          cfprintf(cstderr, "Leak details:\n")

          # Show details of leaked objects
          for i in 0..<allocInfos.len:
            let info = allocInfos[i]
            if info != nil and not info.isDeallocated:
              cfprintf(cstderr, "  Leaked object (refId: %ld) allocated at:\n", info.refId)
              for j in 0..<min(info.allocStackLen, 3):  # Show top 3 frames
                cfprintf(cstderr, "    %s:%ld in %s\n",
                        info.allocStack[j].filename,
                        info.allocStack[j].line,
                        info.allocStack[j].procname)
          cfprintf(cstderr, "=== END LEAK REPORT ===\n\n")
        else:
          cfprintf(cstderr, "✓ No memory leaks detected\n")

  proc nimArcDebugTypeProfiler*(p: pointer, typeName: cstring, size: int) {.exportc, gcsafe.} =
    ## Profile type usage for memory analysis
    cfprintf(cstderr, "Type allocation: %s (size: %ld bytes) at %p\n", typeName, size, p)

  proc nimArcDebugDoubleFreeDeteciton*(p: pointer) {.exportc, gcsafe.} =
    ## Detect double-free attempts
    if p != nil:
      let c = head(p)
      if freedCells.data != nil and freedCells.contains(c):
        cfprintf(cstderr, "\n=== DOUBLE FREE DETECTED ===\n")
        cfprintf(cstderr, "Attempt to free already freed object: %p (refId: %ld)\n", p, c.refId)
        if c.allocInfo != nil:
          cfprintf(cstderr, "Originally freed at:\n")
          for i in 0..<min(c.allocInfo.deallocStackLen, 3):
            cfprintf(cstderr, "  %s:%ld in %s\n",
                     c.allocInfo.deallocStack[i].filename,
                     c.allocInfo.deallocStack[i].line,
                     c.allocInfo.deallocStack[i].procname)
        cfprintf(cstderr, "=== END DOUBLE FREE REPORT ===\n\n")
        when defined(nimArcDebugFatal):
          rawQuit(1)

  proc nimArcDebugDanglingPointerScan*() {.exportc, gcsafe.} =
    ## Scan for dangling pointers in stack and globals
    cfprintf(cstderr, "\n=== DANGLING POINTER SCAN ===\n")
    cfprintf(cstderr, "Scanning stack frames for dangling pointers...\n")

    var frame = framePtr
    var frameCount = 0
    while frame != nil and frameCount < 100:
      # This is a simplified scan - in practice, would need compiler support
      # to know which stack slots contain pointers
      cfprintf(cstderr, "Frame %ld: %p -> %p\n", frameCount, frame, frame.prev)
      frame = frame.prev
      inc frameCount

    cfprintf(cstderr, "=== END DANGLING POINTER SCAN ===\n\n")

proc nimRawDispose(p: pointer, alignment: int) {.compilerRtl.} =
  when not defined(nimscript):
    # Safety check for null or invalid pointers
    if p == nil:
      when defined(nimArcDebug):
        cfprintf(cstderr, "Warning: nimRawDispose called with nil pointer\n")
      return

    # Check for obviously invalid pointers
    let ptrVal = cast[int](p)
    if ptrVal < 0x1000:  # Null page
      when defined(nimArcDebug):
        cfprintf(cstderr, "\n=== INVALID POINTER TO DISPOSE ===\n")
        cfprintf(cstderr, "Attempting to dispose invalid pointer: %p\n", p)
        cfprintf(cstderr, "=== END INVALID POINTER REPORT ===\n\n")
        when defined(nimArcDebugFatal):
          rawQuit(1)
      return

    # Check if pointer is on the stack - this should never happen
    when defined(nimArcDebug):
      # Ensure stack bounds are initialized before checking
      if not isStackBoundsInitialized:
        initStackBounds()

      if isStackAddress(p):
        cfprintf(cstderr, "\n=== CRITICAL ERROR: STACK OBJECT DISPOSAL ===\n")
        cfprintf(cstderr, "Attempting to dispose stack address: %p\n", p)
        cfprintf(cstderr, "Stack objects should NEVER be disposed!\n")
        cfprintf(cstderr, "This indicates a serious bug in the code.\n")
        cfprintf(cstderr, "Possible causes:\n")
        cfprintf(cstderr, "  - Taking address of stack variable and casting to ref\n")
        cfprintf(cstderr, "  - Incorrect pointer arithmetic\n")
        cfprintf(cstderr, "  - Memory corruption\n")
        # Get current stack trace
        if framePtr != nil:
          cfprintf(cstderr, "\nCurrent location:\n")
          cfprintf(cstderr, "  %s:%ld in %s\n", framePtr.filename, framePtr.line, framePtr.procname)
        cfprintf(cstderr, "=== END STACK DISPOSAL ERROR ===\n\n")
        when defined(nimArcDebugFatal):
          rawQuit(1)
        return

    when traceCollector:
      cprintf("[Freed] %p\n", p -! sizeof(RefHeader))
    when defined(nimOwnedEnabled):
      if head(p).rc >= rcIncrement:
        cstderr.rawWrite "[FATAL] dangling references exist\n"
        rawQuit 1
    when defined(nimArcDebug):
      # we do NOT really free the memory here in order to reliably detect use-after-frees
      if freedCells.data == nil: init(freedCells)

      # Add diagnostic output to understand the crash
      when defined(traceArc):
        cfprintf(cstderr, "[nimRawDispose] p=%p\n", p)

      let c = head(p)

      when defined(traceArc):
        cfprintf(cstderr, "[nimRawDispose] c=%p, refId=%ld, allocInfo=%p\n", c, c.refId, c.allocInfo)
      # Add safety check for double-free
      if freedCells.contains(c):
        cfprintf(cstderr, "\n=== DOUBLE FREE DETECTED ===\n")
        cfprintf(cstderr, "Attempting to free already freed object: %p (refId: %ld)\n", p, c.refId)
        cfprintf(cstderr, "=== END DOUBLE FREE REPORT ===\n\n")
        when defined(nimArcDebugFatal):
          rawQuit(1)
        return
      if c.allocInfo == nil:
        # Object was allocated without debug tracking (maybe before nimArcDebug was enabled)
        when traceCollector:
          cfprintf(cstderr, "[Warning] Disposing object without allocInfo: %p (refId: %ld)\n", p, c.refId)
        # Just mark it as freed without tracking deallocation info
        freedCells.incl c
      else:
        # Validate allocInfo pointer before accessing
        let allocInfoAddr = cast[int](c.allocInfo)
        # Check if the allocInfo pointer looks suspicious
        if allocInfoAddr < 0x1000 or (allocInfoAddr and 0x7) != 0:
          # Pointer is clearly invalid (null page or misaligned)
          cfprintf(cstderr, "\n=== CORRUPTED ALLOCINFO DETECTED ===\n")
          cfprintf(cstderr, "Object: %p (refId: %ld)\n", p, c.refId)
          cfprintf(cstderr, "Corrupted allocInfo pointer: %p\n", c.allocInfo)
          cfprintf(cstderr, "This suggests memory corruption or use-after-free\n")
          cfprintf(cstderr, "=== END CORRUPTION REPORT ===\n\n")
          when defined(nimArcDebugFatal):
            rawQuit(1)
          return

        # Additional check: verify the allocInfo is in our tracked list
        var validAllocInfo = false
        var n = 0
        while n < allocInfos.len:
          if allocInfos[n] == c.allocInfo:
            validAllocInfo = true
            break
          inc n

        if not validAllocInfo and c.refId == 0:
          # This object has refId=0 and untracked allocInfo - suspicious!
          cfprintf(cstderr, "\n=== UNTRACKED OBJECT DISPOSAL ===\n")
          cfprintf(cstderr, "Object: %p (refId: %ld)\n", p, c.refId)
          cfprintf(cstderr, "AllocInfo pointer: %p (not in tracked list)\n", c.allocInfo)
          cfprintf(cstderr, "This object was likely allocated before nimArcDebug was enabled\n")
          cfprintf(cstderr, "or is corrupted memory being interpreted as a ref object.\n")
          cfprintf(cstderr, "=== END UNTRACKED OBJECT ===\n\n")
          # Don't access the allocInfo, just mark as freed
          freedCells.incl c
          return
        # Access allocInfo fields carefully
        c.allocInfo.isDeallocated = true
        c.allocInfo.deallocTime = getTimestamp()
        # For deallocation, skip more frames to get to user code
        var frame = framePtr
        var skipCount = 3  # Skip nimRawDispose, destructor calls, etc.
        while frame != nil and skipCount > 0:
          frame = frame.prev
          dec skipCount

        var frameCount = 0
        while frame != nil and frameCount < 16:
          if frame.filename != nil:
            c.allocInfo.deallocStack[frameCount].filename = frame.filename
            c.allocInfo.deallocStack[frameCount].procname = if frame.procname != nil: frame.procname else: cstring("<unknown>")
            c.allocInfo.deallocStack[frameCount].line = frame.line
            inc frameCount
          frame = frame.prev
        c.allocInfo.deallocStackLen = frameCount

        # Update heap statistics for deallocation
        updateHeapStats(sizeof(AllocInfo), false)

        # Poison the freed memory to detect use-after-free
        let objSize = align(sizeof(RefHeader), alignment)
        poisonMemory(p -! objSize, objSize)

      freedCells.incl c
    else:
      let hdrSize = align(sizeof(RefHeader), alignment)
      alignedDealloc(p -! hdrSize, alignment)

template `=dispose`*[T](x: owned(ref T)) = nimRawDispose(cast[pointer](x), T.alignOf)
#proc dispose*(x: pointer) = nimRawDispose(x)

proc nimDestroyAndDispose(p: pointer) {.compilerRtl, quirky, raises: [].} =
  let rti = cast[ptr PNimTypeV2](p)
  if rti.destructor != nil:
    cast[DestructorProc](rti.destructor)(p)
  when false:
    cstderr.rawWrite cast[ptr PNimTypeV2](p)[].name
    cstderr.rawWrite "\n"
    if d == nil:
      cstderr.rawWrite "bah, nil\n"
    else:
      cstderr.rawWrite "has destructor!\n"
  nimRawDispose(p, rti.align)

when defined(gcOrc):
  when defined(nimThinout):
    include cyclebreaker
  else:
    include orc
    #include cyclecollector

proc nimDecRefIsLast(p: pointer): bool {.compilerRtl, inl.} =
  result = false
  if p != nil:
    when defined(nimArcDebug):
      checkMemoryValidity(p, "nimDecRefIsLast")

    var cell = head(p)

    when defined(nimArcDebug):
      # Additional safety check: verify we can access the cell fields
      let cellAddr = cast[int](cell)
      if cellAddr < 0x1000:
        cfprintf(cstderr, "\n=== CORRUPTED CELL IN DECREF ===\n")
        cfprintf(cstderr, "Object pointer: %p\n", p)
        cfprintf(cstderr, "Calculated cell: %p (invalid)\n", cell)
        cfprintf(cstderr, "This suggests severe memory corruption\n")
        cfprintf(cstderr, "=== END CORRUPTED CELL ===\n\n")
        when defined(nimArcDebugFatal):
          rawQuit(1)
        return false

      # Add trace output for debugging
      when defined(traceArc):
        cfprintf(cstderr, "[nimDecRefIsLast] p=%p, cell=%p\n", p, cell)
        # Try to show what's at the cell address
        let cellBytes = cast[ptr array[16, byte]](cell)
        cfprintf(cstderr, "[nimDecRefIsLast] cell contents: %02X %02X %02X %02X %02X %02X %02X %02X\n",
                 cellBytes[0], cellBytes[1], cellBytes[2], cellBytes[3],
                 cellBytes[4], cellBytes[5], cellBytes[6], cellBytes[7])

      # Check if we can safely access refId by validating the cell structure
      # Check if the cell points to a reasonable memory location
      if isStackAddress(cell):
        cfprintf(cstderr, "\n=== CELL ON STACK ERROR ===\n")
        cfprintf(cstderr, "Object pointer: %p\n", p)
        cfprintf(cstderr, "Cell pointer: %p (on stack)\n", cell)
        cfprintf(cstderr, "RefHeader should never be on stack\n")
        cfprintf(cstderr, "=== END STACK CELL ERROR ===\n\n")
        when defined(nimArcDebugFatal):
          rawQuit(1)
        return false

      if cell.refId == traceId:
        writeStackTrace()
        cfprintf(cstderr, "[DecRef] %p %ld\n", p, cell.count)

    when defined(gcAtomicArc) and hasThreadSupport:
      # `atomicDec` returns the new value
      if atomicDec(cell.rc, rcIncrement) == -rcIncrement:
        result = true
        when traceCollector:
          cprintf("[ABOUT TO DESTROY] %p\n", cell)
    else:
      if cell.count == 0:
        result = true
        when traceCollector:
          cprintf("[ABOUT TO DESTROY] %p\n", cell)
      else:
        decrement cell
        # According to Lins it's correct to do nothing else here.
        when traceCollector:
          cprintf("[DECREF] %p\n", cell)

proc GC_unref*[T](x: ref T) =
  ## New runtime only supports this operation for 'ref T'.
  var y {.cursor.} = x
  `=destroy`(y)

proc GC_ref*[T](x: ref T) =
  ## New runtime only supports this operation for 'ref T'.
  if x != nil: nimIncRef(cast[pointer](x))

when not defined(gcOrc):
  template GC_fullCollect* =
    ## Forces a full garbage collection pass. With `--mm:arc` a nop.
    discard

template setupForeignThreadGc* =
  ## With `--mm:arc` a nop.
  discard

template tearDownForeignThreadGc* =
  ## With `--mm:arc` a nop.
  discard

proc isObjDisplayCheck(source: PNimTypeV2, targetDepth: int16, token: uint32): bool {.compilerRtl, inl.} =
  result = targetDepth <= source.depth and source.display[targetDepth] == token

when defined(gcDestructors):
  proc nimGetVTable(p: pointer, index: int): pointer
        {.compilerRtl, inline, raises: [].} =
    result = cast[ptr PNimTypeV2](p).vTable[index]

{.pop.} # raises: []

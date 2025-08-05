# Test for {.noinit.} ref variables initialization bug fix
# Issue: {.noinit.} ref variables were left uninitialized (containing garbage)
# instead of being initialized to nil, causing crashes in ref counting operations.

discard """
  output: '''
stackRef1.value: 123
stackRef.value: 123
'''
"""

type
  RefObj = ref object
    value: int
  Wrapper[T] = ref object of RootObj
    v: T

template unpackObj[T](result: var T, f: RootRef) =
  when T is RootRef:
    result = T(f)
  else:
    let wrapper = Wrapper[T](f)
    result = wrapper.v

proc testIssue() =
  # Test without closure first
  var stackRef1 {.noinit.}: RefObj
  let originalObj = RefObj(value: 123)
  let wrapper = Wrapper[RefObj](v: originalObj)
  let rootRef = RootRef(wrapper)
  unpackObj(stackRef1, rootRef)
  echo "stackRef1.value: ", stackRef1.value

  # Now test with closure - this used to crash due to uninitialized ref
  let closure = proc(this: RootRef) {.closure.} =
    var stackRef {.noinit.}: RefObj
    unpackObj(stackRef, this)
    echo "stackRef.value: ", stackRef.value

  closure(rootRef)

testIssue()

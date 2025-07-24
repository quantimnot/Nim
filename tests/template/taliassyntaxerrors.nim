discard """
  cmd: "nim check --hints:off $file"
"""

block: # with params
  type Foo = object
    bar: int

  var foo = Foo(bar: 10)
  template bar(x: int): int = x + foo.bar
  let a = bar #[tt.Error
      ^ invalid type: 'template (x: int): int' [1] for let [2]
  [1] taliassyntaxerrors.nim(11, 7)
  [2] taliassyntaxerrors.nim(11, 3). Did you mean to call the template with '()'?]#
  bar = 15 #[tt.Error
  ^ 'bar' cannot be assigned to]#

block: # generic template
  type Foo = object
    bar: int

  var foo = Foo(bar: 10)
  template bar[T]: T = T(foo.bar)
  let a = bar #[tt.Error
          ^ 'bar' has unspecified generic parameters; tt.Error
      ^ invalid type: 'template (): T' [1] for let [2]
  [1] taliassyntaxerrors.nim(24, 7)
  [2] taliassyntaxerrors.nim(24, 3). Did you mean to call the template with '()'?]#
  let b = bar[float]()
  doAssert b == 10.0
  bar = 15 #[tt.Error
  ^ 'bar' cannot be assigned to]#

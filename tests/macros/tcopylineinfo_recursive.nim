import macros

macro testCopyLineInfoRecursive(): untyped =
  # Create a source AST with line info
  let srcAst = quote do:
    proc testProc() =
      let x = 42
      echo x
      if x > 0:
        echo "positive"

  # Create a destination AST without line info
  let destAst = newStmtList(
    newProc(
      name = ident"anotherProc",
      body = newStmtList(
        newLetStmt(ident"y", newLit(99)),
        newCall(ident"echo", ident"y")
      )
    )
  )

  # Copy line info recursively from source to destination
  copyLineInfoRecursively(destAst, srcAst)

  # Verify the operation worked by checking the AST has line info
  # The actual line info values will be from the quote block
  doAssert destAst.lineInfoObj.line != 0

  result = destAst

# Test basic usage
testCopyLineInfoRecursive()

# Test with nested structures
macro testNestedCopy(): untyped =
  let src = quote do:
    block outer:
      block inner:
        var z = 100
        z += 1

  let dest = newTree(nnkBlockStmt,
    ident"myBlock",
    newStmtList(
      newTree(nnkBlockStmt,
        ident"nestedBlock",
        newStmtList(
          newVarStmt(ident"w", newLit(200))
        )
      )
    )
  )

  copyLineInfoRecursively(dest, src)

  # Check that nested nodes also have line info
  doAssert dest.lineInfoObj.line != 0
  doAssert dest[1][0].lineInfoObj.line != 0  # nested block should have line info

  result = newEmptyNode()

testNestedCopy()

# Test edge case: empty nodes
macro testEmptyNodes(): untyped =
  let src = newEmptyNode()
  let dest = newEmptyNode()

  # Should not crash on empty nodes
  copyLineInfoRecursively(dest, src)
  result = newEmptyNode()

testEmptyNodes()

# Test with different node types
macro testVariousNodeTypes(): untyped =
  let src = quote do:
    type MyType = object
      field1: int
      field2: string

    const MyConst = 42

    template myTemplate(): untyped =
      echo "template"

  # Create various destination node types
  let typeSection = newTree(nnkTypeSection,
    newTree(nnkTypeDef,
      ident"AnotherType",
      newEmptyNode(),
      newTree(nnkObjectTy,
        newEmptyNode(),
        newEmptyNode(),
        newTree(nnkRecList,
          newIdentDefs(ident"a", ident"int")
        )
      )
    )
  )

  copyLineInfoRecursively(typeSection, src)
  doAssert typeSection.lineInfoObj.line != 0

  result = newEmptyNode()

testVariousNodeTypes()

# Test difference between copyLineInfo and copyLineInfoRecursively
macro testCopyLineInfoDifference(): untyped =
  # Create a simple source AST with line info from quote
  let src = quote do:
    block sourceBlock:
      echo "line 1"
      echo "line 2"

  # Create two identical destination ASTs
  let dest1 = newTree(nnkBlockStmt,
    ident"dest1Block",
    newStmtList(
      newCall(ident"print", newLit("test1")),
      newCall(ident"print", newLit("test2"))
    )
  )

  let dest2 = newTree(nnkBlockStmt,
    ident"dest2Block",
    newStmtList(
      newCall(ident"print", newLit("test3")),
      newCall(ident"print", newLit("test4"))
    )
  )

  # Get line info before copying
  let srcRootLine = src.lineInfoObj.line

  # Store original dest child line info
  let dest1Child1OrigLine = dest1[1][0].lineInfoObj.line

  # Apply copyLineInfo to dest1 - should only affect root
  copyLineInfo(dest1, src)

  # Apply copyLineInfoRecursively to dest2 - should affect all nodes
  copyLineInfoRecursively(dest2, src)

  # Verify copyLineInfo only copied to root
  doAssert dest1.lineInfoObj.line == srcRootLine, "copyLineInfo should copy root line"
  doAssert dest1[1][0].lineInfoObj.line == dest1Child1OrigLine, "copyLineInfo should not change child line info"

  # Verify copyLineInfoRecursively copied to all nodes with the root's line info
  # Note: copyLineInfoRecursively copies the root's line info to all nodes recursively
  doAssert dest2.lineInfoObj.line == srcRootLine, "copyLineInfoRecursively should copy root line"
  doAssert dest2[1][0].lineInfoObj.line == srcRootLine, "copyLineInfoRecursively should copy root line info to all children"
  doAssert dest2[1][1].lineInfoObj.line == srcRootLine, "copyLineInfoRecursively should copy root line info to all children"

  # The key difference demonstrated:
  # - copyLineInfo: only updates the root node's line info
  # - copyLineInfoRecursively: updates all nodes' line info with the source root's line info

  result = newEmptyNode()

testCopyLineInfoDifference()

# Compile-time verification that the proc exists and works
static:
  let staticSrc = newLit(42)
  let staticDest = newLit(99)
  copyLineInfoRecursively(staticDest, staticSrc)
  doAssert staticDest.intVal == 99  # value should remain unchanged

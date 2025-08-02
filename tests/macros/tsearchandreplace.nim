import std/macros
from std/strutils import contains, count

macro testSearchAndReplace =
  ## Comprehensive test for all search and replace functionality

  # Test 1: Basic DFS integer replacement
  var testNode1 = nnkInfix.newTree(newIdentNode("+"), newLit(5), newLit(10))
  depthFirstSearchAndReplace(testNode1, newLit(99), newLit(5))
  doAssert testNode1.repr.contains("99")
  doAssert testNode1.repr.contains("10")

  # Test 2: Basic BFS multiple replacement
  var testNode2 = nnkInfix.newTree(
    newIdentNode("+"),
    nnkInfix.newTree(newIdentNode("+"), newLit(5), newLit(3)),
    newLit(5)
  )
  breadthFirstSearchAndReplace(testNode2, newLit(88), newLit(5))
  doAssert testNode2.repr.count("88") == 2
  doAssert testNode2.repr.contains("3")

  # Test 3: Multi-pattern DFS using seq
  var testNode3 = nnkStmtList.newTree(
    nnkVarSection.newTree(
      nnkIdentDefs.newTree(newIdentNode("x"), newEmptyNode(), newLit(10))
    ),
    nnkVarSection.newTree(
      nnkIdentDefs.newTree(newIdentNode("y"), newEmptyNode(), newLit(20))
    )
  )
  let patterns3 = @[newLit(10), newLit(20)]
  depthFirstSearchAndReplaceSeq(testNode3, newLit(999), patterns3)
  doAssert testNode3.repr.count("999") == 2

  # Test 4: Multi-pattern BFS using seq
  var testNode4 = nnkTypeSection.newTree(
    nnkTypeDef.newTree(
      ident"Type1",
      newEmptyNode(),
      nnkDotExpr.newTree(ident"VFS", ident"FileMode")
    ),
    nnkTypeDef.newTree(
      ident"Type2",
      newEmptyNode(),
      nnkDotExpr.newTree(ident"This", ident"FileMode")
    )
  )
  let patterns4 = @[
    nnkDotExpr.newTree(ident"VFS", ident"FileMode"),
    nnkDotExpr.newTree(ident"This", ident"FileMode")
  ]
  breadthFirstSearchAndReplaceSeq(testNode4, ident"REPLACED", patterns4)
  doAssert testNode4.repr.count("REPLACED") == 2

  # Test 5: Structural matching (single pattern)
  var testNode5 = nnkStmtList.newTree(
    nnkVarSection.newTree(
      nnkIdentDefs.newTree(newIdentNode("x"), newEmptyNode(), newLit(10))
    ),
    nnkAsgn.newTree(newIdentNode("y"), newLit(20))
  )
  depthFirstSearchAndReplaceStructural(testNode5, newIdentNode("STRUCT"), newIdentNode("anyName"))
  let structCount = testNode5.repr.count("STRUCT")
  doAssert structCount == 2, "Expected 2 STRUCT replacements, got " & $structCount & " in: " & testNode5.repr

  # Test 6: Structural matching (multi-pattern seq)
  var testNode6 = nnkStmtList.newTree(
    nnkVarSection.newTree(
      nnkIdentDefs.newTree(newIdentNode("a"), newEmptyNode(), newLit(100))
    ),
    nnkAsgn.newTree(newIdentNode("b"), newLit(200))
  )
  let structPatterns = @[
    newIdentNode("dummyIdent"),  # nkIdent pattern
    newLit(999)                  # nkIntLit pattern
  ]
  depthFirstSearchAndReplaceStructuralSeq(testNode6, newIdentNode("MULTI_STRUCT"), structPatterns)
  doAssert testNode6.repr.count("MULTI_STRUCT") >= 4  # Should replace both identifiers and both literals

  # Test 7: Structural BFS matching
  var testNode7 = nnkStmtList.newTree(
    nnkCall.newTree(newIdentNode("proc1")),
    nnkCall.newTree(newIdentNode("proc2")),
    nnkInfix.newTree(newIdentNode("+"), newLit(1), newLit(2))
  )
  breadthFirstSearchAndReplaceStructural(testNode7, newIdentNode("CALL_REPLACED"),
                                         nnkCall.newTree(newIdentNode("dummy")))
  doAssert testNode7.repr.count("CALL_REPLACED") == 2

  # Test 8: Edge cases
  var emptyNode = newEmptyNode()
  depthFirstSearchAndReplace(emptyNode, newLit(1), newLit(2))
  doAssert emptyNode.kind == nnkEmpty

  var rootNode = newLit(42)
  depthFirstSearchAndReplace(rootNode, newLit(99), newLit(42))
  doAssert rootNode.intVal == 42  # Root should not be replaced

  # Test 9: String literals
  var strNode = nnkCall.newTree(newIdentNode("echo"), newStrLitNode("hello"))
  depthFirstSearchAndReplace(strNode, newStrLitNode("goodbye"), newStrLitNode("hello"))
  doAssert strNode.repr.contains("goodbye")

  # Test 10: Float literals
  var floatNode = nnkInfix.newTree(newIdentNode("+"), newFloatLitNode(3.14), newFloatLitNode(2.71))
  depthFirstSearchAndReplace(floatNode, newFloatLitNode(1.0), newFloatLitNode(3.14))
  doAssert floatNode.repr.contains("1.0")

  # Test 11: Case sensitivity check
  var caseNode = nnkInfix.newTree(newIdentNode("+"), newIdentNode("myVar"), newLit(5))
  var exactTest = caseNode.copyNimTree()
  depthFirstSearchAndReplace(exactTest, newIdentNode("EXACT_MATCH"), newIdentNode("myVar"))
  doAssert exactTest.repr.contains("EXACT_MATCH")

testSearchAndReplace()

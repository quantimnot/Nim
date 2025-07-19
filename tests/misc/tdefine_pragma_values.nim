discard """
joinable: false
cmd: "nim c $options -r $file"
"""

# Test for pragma define with values feature
# Tests the new {.define(symbol, value).} syntax

# Test string values
{.define(pragmaStr, "hello").}
{.define(pragmaStr2, "world").}

# Test integer values  
{.define(pragmaInt, 42).}
{.define(pragmaInt2, 123).}

# Test identifier values (like true/false)
{.define(pragmaBool, true).}
{.define(pragmaBool2, false).}

# Test that symbols are defined
doAssert defined(pragmaStr)
doAssert defined(pragmaStr2)
doAssert defined(pragmaInt)
doAssert defined(pragmaInt2)
doAssert defined(pragmaBool)
doAssert defined(pragmaBool2)

# Test that values are correctly stored
const pragmaStr {.strdefine.} = "default"
const pragmaStr2 {.strdefine.} = "default2"
const pragmaInt {.intdefine.} = 0
const pragmaInt2 {.intdefine.} = 0
const pragmaBool {.booldefine.} = false
const pragmaBool2 {.booldefine.} = true

# Verify values match what was defined in pragma
doAssert pragmaStr == "hello"
doAssert pragmaStr2 == "world"
doAssert pragmaInt == 42
doAssert pragmaInt2 == 123
doAssert pragmaBool == true
doAssert pragmaBool2 == false

# Test that existing syntax still works
{.define: oldSyntax.}
doAssert defined(oldSyntax)

# Test mixed usage - this should use the pragma value since no CLI override
const mixedTest {.strdefine: "pragmaStr".} = "defaultMixed"
doAssert mixedTest == "hello"

echo "All pragma define value tests passed!"
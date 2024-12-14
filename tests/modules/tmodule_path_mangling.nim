#!/usr/bin/env testament --ignorePathStructureConstraints run
discard """
  # joinable: true
  matrix: ""
  # targets: "c cpp js objc"
  output: ""
"""

import std/[strutils, os]

from ../../compiler/pathutils import RelativeFile
import ../../compiler/modulepaths {.all.}

when not declared(doAssert): import std/assertions

import std/[unittest, strformat]
import minlib/test/test/nimbench/nimbench
import minlib/language/metaprogramming

proc calcCompressionRatio(i, o: string) =
  template ratio: untyped = i.len / o.len
  echo &"compression ratio: {ratio:>4.2f}"

macro benchTimeCheck(encoderA, decoderA, encoderB, decoderB: untyped{nkIdent}, inputs, codecAOutputs, codecBOutputs: untyped{nkStmtList}): untyped =
  result = newStmtList()
  block checkOutputs:
    let encoderAName = newLit encoderA.strVal
    let decoderAName = newLit decoderA.strVal
    let encoderBName = newLit encoderB.strVal
    let decoderBName = newLit decoderB.strVal
    let compRatioA = ident"compRatioA"
    let compRatioB = ident"compRatioB"
    let relativeCompRatio = ident"relativeCompRatio"
    var tests = newStmtList()
    var codecAChecks = newStmtList()
    var codecBChecks = newStmtList()
    for i in 0..<inputs.len:
      template input: untyped = inputs[i]
      template encoderAOutput: untyped = codecAOutputs[i][0]
      template decoderAOutput: untyped = codecAOutputs[i][1]
      template encoderBOutput: untyped = codecBOutputs[i][0]
      template decoderBOutput: untyped = codecBOutputs[i][1]
      tests.add quote do:
        test `input`:
          let encodedA = `encoderA`(`input`)
          check encodedA == `encoderAOutput`
          let decodedA = `decoderA`(encodedA)
          check decodedA == `decoderAOutput`
          let `compRatioA` = `input`.len / encodedA.len
          let encodedB = `encoderB`(`input`)
          check encodedB == `encoderBOutput`
          let decodedB = `decoderB`(encodedB)
          check decodedB == `decoderBOutput`
          let `compRatioB` = `input`.len / encodedB.len
          let `relativeCompRatio` = "(" & $(100 * `compRatioB` / `compRatioA`) & "%)"
          echo `encoderAName` & &" compression ratio: {compRatioA:>4.2f}"
          echo `encoderBName` & &" compression ratio: {compRatioB:>4.2f}  {relativeCompRatio}"
          block:
            bench(`encoderA`, m):
              var encoded: string
              for i in 1..m:
                encoded = `encoderA`(`input`)
              doNotOptimizeAway encoded
            benchRelative(`encoderB`, m):
              var encoded: string
              for i in 1..m:
                encoded = `encoderB`(`input`)
              doNotOptimizeAway encoded
          block:
            bench(`decoderA`, m):
              var decoded: string
              for i in 1..m:
                decoded = `decoderA`(`input`)
              doNotOptimizeAway decoded
            benchRelative(`decoderB`, m):
              var decoded: string
              for i in 1..m:
                decoded = `decoderB`(`input`)
              doNotOptimizeAway decoded
      # codecAChecks.add quote do:
      #   test `input`:
      #     let encodedA = `encoderA`(`input`)
      #     check encodedA == `encoderAOutput`
      #     let decodedA = `decoderA`(encodedA)
      #     check decodedA == `decoderAOutput`
      #     let `compRatioA` = `input`.len / encodedA.len
      #     let encodedB = `encoderB`(`input`)
      #     check encodedB == `encoderBOutput`
      #     let decodedB = `decoderB`(encodedB)
      #     check decodedB == `decoderBOutput`
      #     let `compRatioB` = `input`.len / encodedB.len
      #     echo &"`{codecNameA}` compression ratio: {compressionRatioA:>4.2f}"
      #     echo &"`{codecNameB}` compression ratio: {compressionRatioB:>4.2f}"
      #     block:
      #       bench(`encoderA`, m):
      #         var encoded: string
      #         for i in 1..m:
      #           encoded = `encoderA`(`input`)
      #         doNotOptimizeAway encoded
      # codecBChecks.add quote do:
      #   test `input`:
      #     let encoded = `encoderB`(`input`)
      #     check encoded == `encoderBOutput`
      #     let decoded = `decoderB`(encoded)
      #     check decoded == `decoderBOutput`
      #     let `compRatio` = `input`.len / encoded.len
      #     echo &"compression ratio: {compressionRatio:>4.2f}"
      #     block:
      #       benchRelative(`encoderB`, m):
      #         var encoded: string
      #         for i in 1..m:
      #           encoded = `encoderB`(`input`)
      #         doNotOptimizeAway encoded
    result.add tests
    # result.add quote do:
    #   suite `encoderAName`:
    #     `codecAChecks`
    #   suite `encoderBName`:
    #     `codecBChecks`
  # block measureExecTime:
  #   let mangledIdent = genSym(nskVar, "mangled")
  #   var inputs = newStmtList()
  # for i in 0..<inputs.len:
  #   inputs.add newAssignment(mangledIdent, newCall(impl, inputs[i]))
  #   checkMangledValues.add newCall(bindSym"check", newCall(bindSym"==", newCall(impl, inputs[i]), outputs[i]))
  #   # calcCompressionRatios.add newCall(bindSym"calcCompressionRatio", newLit strVal expr[lhs], newLit strVal expr[rhs])
  # result = genAst(benchCall, mangledIdent, impl, inputs, outputs, checkMangledValues, calcCompressionRatios):
  #   benchCall(impl, m):
  #     var mangledIdent: string
  #     for i in 1..m:
  #       inputs
  #     doNotOptimizeAway mangledIdent
  #   checkMangledValues
  #   # calcCompressionRatios
  debugEcho result.repr

# macro benchTimeCheck(oldImpl, newImpl: untyped{nkIdent}, inputs, oldOutputs, newOutputs: untyped{nkStmtList}): untyped =
#   mixin oldImpl, newImpl
#   benchTimeCheckImpl(oldImpl, newImpl, inputs, oldOutputs, newOutputs)

# template benchRelativeTimeCheck(impl: untyped, exprs: untyped{nkStmtList}): untyped =
#   mixin impl
#   benchTimeCheckImpl(impl, exprs, benchCall = nimbench.benchRelative)

converter toRelativeFile(s: string): RelativeFile = RelativeFile s


benchTimeCheck(oldMangleModuleNameImpl, oldDemangleModuleNameImpl, mangleModuleNameImpl, demangleModuleNameImpl):
  # IMPORTANT: the order of the inputs must match the order of the expected outputs
  ""
  $os.DirSep
  $os.AltSep
  "#"
  "@"
  ":"
  &"..{os.DirSep}"
  &"..{os.DirSep}####"
  "@@"
  ".."
  repeat(&"..{os.DirSep}", 20)
do: # expected (encoderOutput, decoderOutput) pairs for old impl
  ("@m", "")
  ("@m@s", $os.DirSep)
  ("@m@s", $os.DirSep) # old impl normalizes the separators
  ("@m@h", "#")
  ("@m@@", "@")
  ("@m@c", ":")
  ("@m..@s", &"..{os.DirSep}")
  ("@m..@s@h@h@h@h", &"..{os.DirSep}####")
  ("@m@@@@", "@@")
  ("@m..", "..")
  ("@m" & repeat(&"..@s", 20), repeat(&"..{os.DirSep}", 20))
do: # expected (encoderOutput, decoderOutput) pairs for new impl
  ("@m", "")
  ("@m@s", $os.DirSep)
  ( # new impl doesn't normalize the separators
    (when os.DirSep == os.AltSep: "@m@s" else: "@m@a"),
    (when os.DirSep == os.AltSep: $os.DirSep else: $os.AltSep)
  )
  ("@m@h", "#")
  ("@m@@", "@")
  ("@m@c", ":")
  ("@m@p", &"..{os.DirSep}") # `@p` is a new subsitute for the common `../`
  ("@m@p@4h", &"..{os.DirSep}####")
  ("@m@2@", "@@")
  ("@m..", "..") #("@m@2d", "..") # `@d` is a new subsitute for `.`
  ("@m@20p", repeat(&"..{os.DirSep}", 20))

runBenchmarks()

# benchRelativeTimeCheck mangleModuleNameImpl:

# benchTimeCheck oldDemangleModuleNameImpl:
#   "@m..@s" == &"..{os.DirSep}"
#   "@m..@s@h@h@h@h" == &"..{os.DirSep}####"
#   "@m@@@@" == "@@"
#   "@m.." == ".."
#   "@m" == ""
#   "@m@s" == $os.DirSep
#   "@m" & repeat(&"..@s", 20) == repeat(&"..{os.DirSep}", 20)

# benchRelativeTimeCheck demangleModuleNameImpl:
#   "@m@p" == &"..{os.DirSep}"
#   "@m@p@4h" == &"..{os.DirSep}####"
#   "@m@2@" == "@@"
#   "@m.." == ".."
#   "@m" == ""
#   "@m@s" == $os.DirSep
#   "@m@20p" == repeat(&"..{os.DirSep}", 20)

# import std/compilesettings
# const mm = querySetting(SingleValueSetting.mm)
# # const defs = querySettingSeq(MultipleValueSetting.definedSymbols)
# const defs = "vanilla nim c doesn't give clear output for this"
# echo &"mm: {mm} defs: {defs}"
# # runBenchmarks()

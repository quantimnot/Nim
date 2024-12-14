#
#
#           The Nim Compiler
#        (c) Copyright 2017 Contributors
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

import ast, renderer, msgs, options, idents, lineinfos,
  pathutils

import std/[strutils, os, parseutils]

proc getModuleName*(conf: ConfigRef; n: PNode): string =
  # This returns a short relative module name without the nim extension
  # e.g. like "system", "importer" or "somepath/module"
  # The proc won't perform any checks that the path is actually valid
  case n.kind
  of nkStrLit, nkRStrLit, nkTripleStrLit:
    try:
      result = pathSubs(conf, n.strVal, toFullPath(conf, n.info).splitFile().dir)
    except ValueError:
      localError(conf, n.info, "invalid path: " & n.strVal)
      result = n.strVal
  of nkIdent:
    result = n.ident.s
  of nkSym:
    result = n.sym.name.s
  of nkInfix:
    let n0 = n[0]
    let n1 = n[1]
    when false:
      if n1.kind == nkPrefix and n1[0].kind == nkIdent and n1[0].ident.s == "$":
        if n0.kind == nkIdent and n0.ident.s == "/":
          result = lookupPackage(n1[1], n[2])
        else:
          localError(n.info, "only '/' supported with $package notation")
          result = ""
    else:
      if n0.kind in nkIdentKinds:
        let ident = n0.getPIdent
        if ident != nil and ident.s[0] == '/':
          let modname = getModuleName(conf, n[2])
          # hacky way to implement 'x / y /../ z':
          result = getModuleName(conf, n1)
          result.add renderTree(n0, {renderNoComments}).replace(" ")
          result.add modname
        else:
          result = ""
      else:
        result = ""
  of nkPrefix:
    when false:
      if n[0].kind == nkIdent and n[0].ident.s == "$":
        result = lookupPackage(n[1], nil)
      else:
        discard
    # hacky way to implement 'x / y /../ z':
    result = renderTree(n, {renderNoComments}).replace(" ")
  of nkDotExpr:
    localError(conf, n.info, warnDeprecated, "using '.' instead of '/' in import paths is deprecated")
    result = renderTree(n, {renderNoComments}).replace(".", "/")
  of nkImportAs:
    result = getModuleName(conf, n[0])
  else:
    localError(conf, n.info, "invalid module name: '$1'" % n.renderTree)
    result = ""

proc checkModuleName*(conf: ConfigRef; n: PNode; doLocalError=true): FileIndex =
  # This returns the full canonical path for a given module import
  let modulename = getModuleName(conf, n)
  let fullPath = findModule(conf, modulename, toFullPath(conf, n.info))
  if fullPath.isEmpty:
    if doLocalError:
      let m = if modulename.len > 0: modulename else: $n
      localError(conf, n.info, "cannot open file: " & m)
    result = InvalidFileIdx
  else:
    result = fileInfoIdx(conf, fullPath)

proc oldMangleModuleNameImpl*(path: RelativeFile): string =
  result = "@m" & path.string.multiReplace(
    {$os.DirSep: "@s", $os.AltSep: "@s", "#": "@h", "@": "@@", ":": "@c"})

proc oldDemangleModuleNameImpl*(path: RelativeFile): string =
  ## Demangle a relative module path.
  result = path.string.multiReplace({"@p": ".." & $os.DirSep, "@@": "@", "@h": "#", "@s": $os.DirSep, "@a": $os.AltSep, "@m": "", "@c": ":"})

func len(path: RelativeFile): int {.borrow.}
func `[]`(path: RelativeFile, i: int): char = path.string[i]
func `[]`(path: RelativeFile, i: HSlice[system.int, system.BackwardsIndex]): string = path.string[i]
func startsWith(path: RelativeFile, prefix: string): bool {.borrow.}

proc mangleModuleNameImpl*(path: RelativeFile): string =
  const prefix = "@m"
  const matchChars = {'.', '#', os.DirSep, ':', '@'}
  result = newStringOfCap(path.len + prefix.len)
  template add(v: var string, s: var string) =
    v[v.len ..< v.len + s.len] = ensureMove s
    v.setLen v.len + s.len
  result.add prefix
  var candidate: char = '\0'
  var candidateCount = 0
  var i = 0
  template addCandidateToResult: untyped =
    if candidateCount > 0:
      if candidateCount == 1:
        result.add "@" & candidate
      else:
        result.add "@" & $candidateCount & candidate
    candidate = '\0'
    candidateCount = 0
  template incOrSetCandidate(newCandidate) =
    if candidate == newCandidate:
      inc candidateCount
    else:
      addCandidateToResult
      candidate = newCandidate
      candidateCount = 1
  while i < path.len:
    case path[i]
    of '.':
      # Check for '../'
      if i < path.len - 2 and path[i+1] == '.' and path[i+2] == os.DirSep:
        incOrSetCandidate 'p'
        i += 2
      else:
        addCandidateToResult
        result.add path[i]
    of '#': incOrSetCandidate 'h'
    of os.DirSep: incOrSetCandidate 's'
    of ':': incOrSetCandidate 'c'
    of '@': incOrSetCandidate '@'
    else:
      addCandidateToResult
      when os.AltSep notin matchChars:
        if path[i] == os.AltSep: result.add "@a"
        else: result.add path[i]
      else: result.add path[i]
    inc i
  addCandidateToResult # Add any remaining candidate to the result

proc demangleModuleNameImpl(path: RelativeFile): string =
  result = newStringOfCap(path.len)
  var runLenCount = 1
  var expectReplacement = false
  template reset: untyped =
    runLenCount = 1
    expectReplacement = false
  var i = 0
  while i < path.len:
    if expectReplacement:
      case path[i]
      of '@': result.add repeat("@", runLenCount); reset
      of 'p': result.add repeat(".." & os.DirSep, runLenCount); reset
      of '1'..'9':
        i += parseSaturatedNatural(path[i..^1], runLenCount) - 1
      of 's': result.add repeat(os.DirSep, runLenCount); reset
      of 'c': result.add repeat(":", runLenCount); reset
      of 'a': result.add repeat(os.AltSep, runLenCount); reset
      of 'h': result.add repeat("#", runLenCount); reset
      of 'm': reset
      else: raise (ref ValueError)(msg: "unexpected mangled module path value: " & path[i])
    else:
      case path[i]
      of '@': expectReplacement = true
      else: result.add path[i]
    inc i


proc mangleModuleName*(conf: ConfigRef; path: AbsoluteFile): string =
  ## Mangle a relative module path to avoid path and symbol collisions.
  ##
  ## Used by backends that need to generate intermediary files from Nim modules.
  ## This is needed because the compiler uses a flat cache file hierarchy.
  ##
  ## Example:
  ## `foo-#head/../bar` becomes `@foo-@hhead@s..@sbar`
  mangleModuleNameImpl(relativeTo(path, conf.projectPath))

proc demangleModuleName*(path: string): string =
  ## Demangle a relative module path.
  demangleModuleNameImpl(RelativeFile path)

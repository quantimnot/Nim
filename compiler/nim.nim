#
#
#           The Nim Compiler
#        (c) Copyright 2015 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

import std/[os, strutils, parseopt, osproc]

when defined(nimPreviewSlimSystem):
  import std/assertions

when defined(windows):
  when defined(gcc):
    when defined(x86):
      {.link: "../icons/nim.res".}
    else:
      {.link: "../icons/nim_icon.o".}

  when defined(amd64) and defined(vcc):
    {.link: "../icons/nim-amd64-windows-vcc.res".}
  when defined(i386) and defined(vcc):
    {.link: "../icons/nim-i386-windows-vcc.res".}

import
  commands, options, msgs, extccomp, main, idents, lineinfos, cmdlinehelper,
  pathutils, modulegraphs

from std/browsers import openDefaultBrowser
from nodejs import findNodeJs

when hasTinyCBackend:
  import tccgen

when defined(profiler) or defined(memProfiler):
  {.hint: "Profiling support is turned on!".}
  import nimprof

proc nimbleLockExists(config: ConfigRef): bool =
  const nimbleLock = "nimble.lock"
  let pd = if not config.projectPath.isEmpty: config.projectPath else: AbsoluteDir(getCurrentDir())
  if optSkipParentConfigFiles notin config.globalOptions:
    for dir in parentDirs(pd.string, fromRoot=true, inclusive=false):
      if fileExists(dir / nimbleLock):
        return true
  return fileExists(pd.string / nimbleLock)

proc processCmdLine(pass: TCmdLinePass, cmd: string; config: ConfigRef) =
  var p = parseopt.initOptParser(cmd)
  var argsCount = 0

  config.commandLine.setLen 0
    # bugfix: otherwise, config.commandLine ends up duplicated

  while true:
    parseopt.next(p)
    case p.kind
    of cmdEnd: break
    of cmdLongOption, cmdShortOption:
      config.commandLine.add " "
      config.commandLine.addCmdPrefix p.kind
      config.commandLine.add p.key.quoteShell # quoteShell to be future proof
      if p.val.len > 0:
        config.commandLine.add ':'
        config.commandLine.add p.val.quoteShell

      if p.key == "": # `-` was passed to indicate main project is stdin
        p.key = "-"
        if processArgument(pass, p, argsCount, config): break
      else:
        processSwitch(pass, p, config)
    of cmdArgument:
      config.commandLine.add " "
      config.commandLine.add p.key.quoteShell
      if processArgument(pass, p, argsCount, config): break
  if pass == passCmd2:
    if {optRun, optWasNimscript} * config.globalOptions == {} and
        config.arguments.len > 0 and config.cmd notin {cmdTcc, cmdNimscript, cmdCrun}:
      rawMessage(config, errGenerated, errArgsNeedRunOption)

  if config.nimbleLockExists:
    # disable nimble path if nimble.lock is present.
    # see https://github.com/nim-lang/nimble/issues/1004
    disableNimblePath(config)

proc getNimRunExe(conf: ConfigRef): string =
  conf.getConfigVar("nimrun.exe")

proc getNimRunOptionsAlways(conf: ConfigRef): string =
  conf.getConfigVar("nimrun.options.always")

proc getNimRunFormat(conf: ConfigRef): string =
  conf.getConfigVar("nimrun.format", "$runner $runnerOpts $prog $args")

##########################
#region OS Signal Handlers
##########################
import std/exitprocs
import std/posix
when not defined posix:
  {.error: "This program only works on POSIX systems".}
#endregion
var process: Process

proc handleCmdLine(cache: IdentCache; conf: ConfigRef) =
  let self = NimProg(
    supportsStdinFile: true,
    processCmdLine: processCmdLine
  )
  self.initDefinesProg(conf, "nim_compiler")
  if paramCount() == 0:
    writeCommandLineUsage(conf)
    return

  self.processCmdLineAndProjectPath(conf)

  var graph = newModuleGraph(cache, conf)
  if not self.loadConfigsAndProcessCmdLine(cache, conf, graph):
    return

  if conf.cmd == cmdCheck and optWasNimscript notin conf.globalOptions and
       conf.backend == backendInvalid:
    conf.backend = backendC

  if conf.selectedGC == gcUnselected:
    if conf.backend in {backendC, backendCpp, backendObjc} or
        (conf.cmd in cmdDocLike and conf.backend != backendJs) or
        conf.cmd == cmdGendepend:
      initOrcDefines(conf)

  mainCommand(graph)
  if conf.hasHint(hintGCStats): echo(GC_getStatistics())
  #echo(GC_getStatistics())
  if conf.errorCounter != 0: return
  when hasTinyCBackend:
    if conf.cmd == cmdTcc:
      tccgen.run(conf, conf.arguments)
  if optRun in conf.globalOptions:
    let output = conf.absOutFile
    case conf.cmd
    of cmdBackends, cmdTcc:
      let nimRunExe = getNimRunExe(conf)
      let nimRunFmt = getNimRunFormat(conf)
      let nimRunOptionsAlways = getNimRunOptionsAlways(conf)
      if conf.backend notin {backendC, backendCpp, backendObjc, backendJs}:
        raiseAssert "`nim run` not supported for backend: " & $conf.backend
      let cmd =
        (nimRunFmt % [
          "runner", nimRunExe,
          "runnerOpts", nimRunOptionsAlways,
          "prog", output.quoteShell,
          "args", conf.arguments]).strip(leading=true,trailing=true)
      execExternalProgram(conf, cmd.strip(leading=false,trailing=true))
      process = startProcess(cmd, options={poEvalCommand, poParentStreams})
      proc reapChildProcess {.noconv.} =
        terminate process
      proc onTerminate(signal: cint) {.noconv.} =
        when compileOption("threads"):
          # TODO: not sure if this needed, just copy-pasted from an example
          # workaround for https://github.com/nim-lang/Nim/issues/4057
          setupForeignThreadGC()
        reapChildProcess()
      proc setupSignalHandlers() =
        # signal(SIGCHLD, SIG_IGN);
        signal(SIGTERM, onTerminate)
        signal(SIGSTOP, onTerminate)
        signal(SIGKILL, onTerminate)
      setupSignalHandlers()
      if process.waitForExit != QuitSuccess:
        rawMessage(conf, errGenerated, "execution of an external program failed: '$1'" % cmd)
    of cmdDocLike, cmdRst2html, cmdRst2tex, cmdMd2html, cmdMd2tex: # bugfix(cmdRst2tex was missing)
      if conf.arguments.len > 0:
        # reserved for future use
        rawMessage(conf, errGenerated, "'$1 cannot handle arguments" % [$conf.cmd])
      openDefaultBrowser($output)
    else:
      # support as needed
      rawMessage(conf, errGenerated, "'$1 cannot handle --run" % [$conf.cmd])

when declared(GC_setMaxPause):
  GC_setMaxPause 2_000

when compileOption("gc", "refc"):
  # the new correct mark&sweet collector is too slow :-/
  GC_disableMarkAndSweep()

when not defined(selftest):
  let conf = newConfigRef()
  handleCmdLine(newIdentCache(), conf)
  when declared(GC_setMaxPause):
    echo GC_getStatistics()
  msgQuit(int8(conf.errorCounter > 0))

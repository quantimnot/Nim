#
#
#           The Nim Compiler
#        (c) Copyright 2017 Andreas Rumpf
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

iterator myParentDirs(p: string): string =
  # XXX os's parentDirs is stupid (multiple yields) and triggers an old bug...
  var current = p
  while true:
    current = current.parentDir
    if current.len == 0: break
    yield current

proc getNimbleFileImpl(conf: ConfigRef; path: string): string =
  ## returns absolute path to nimble file, e.g.: /pathto/cligen.nimble
  # TODO: looks like uses are just taking the absolute parent dir; no one cares about the nimble path; rename this to
  # TODO: this needs to use `options.findProjectNimFile` to find the root dir
  result = ""
  var parents = 0
  block packageSearch:
    for d in myParentDirs(path):
      if conf.packageCache.hasKey(d):
        #echo "from cache ", d, " |", packageCache[d], "|", path.splitFile.name
        return conf.packageCache[d]
      inc parents
      for file in walkFiles(d / "*.nimble"):
        result = file
        break packageSearch
  # we also store if we didn't find anything:
  for d in myParentDirs(path):
    #echo "set cache ", d, " |", result, "|", parents
    conf.packageCache[d] = result
    dec parents
    if parents <= 0: break
  ## Return the absolute directory path of `modulePath`'s package.

proc getNimbleFile*(conf: ConfigRef; path: string): string {.deprecated: "use `getModulePackageDir`".} =
  getNimbleFileImpl(conf, path)

proc getModulePackageDir*(conf: ConfigRef; modulePath: AbsoluteFile): AbsoluteDir =
  ## Return the absolute directory path of `modulePath`'s package.
  ##
  ## See Also:
  ## * `getModulePackageDir proc<packages.html#getModulePackageDir,ConfigRef,PSym>`_ for lookup by module symbol
  AbsoluteDir getNimbleFileImpl(conf, modulePath.string).parentDir.AbsoluteDir

proc getPackageName*(conf: ConfigRef; path: string): string =
  ## returns nimble package name, e.g.: `cligen`
  let path = getNimbleFileImpl(conf, path)
  if path.len > 0:
    return path.splitFile.name
  else:
    return "unknown" # TODO: how about using a hash of the project dir path? avoids conflicts with a package named 'unknown'

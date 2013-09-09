fs = require('fs')
path = require('path')
mkdirp = require('mkdirp')
stylus = require('stylus')
nib = require('nib')
{Future} = require('../../utils/Future')
{BuildTask} = require('./BuildTask')

pathToCore = "bundles/cord/core"


stylusLib = (style) ->
  style.define('url', stylus.url())
  style.use(nib())
  style.import('nib')

replaceImportRe = /^@import ['"](.*\/\/.+)['"]$/gm

_pathUtils = null
pathUtils = (baseDir) ->
  ###
  Lazy val
  ###
  _pathUtils = require "#{ path.join(baseDir, 'public', pathToCore) }/requirejs/pathUtils" if not _pathUtils?
  _pathUtils

class CompileStylus extends BuildTask

  @totalPreprocessTime: [0, 0]

  run: ->
    dirname = path.dirname(@params.file)
    basename = path.basename(@params.file, '.styl')

    src = "#{ @params.baseDir }/#{ @params.file }"
    dst = "#{ @params.targetDir }/#{ dirname }/#{ basename }.css"

    f = Future.call(fs.readFile, src, 'utf8').flatMap (stylusStr) =>
      pu = pathUtils(@params.baseDir)
      preprocessedStr = stylusStr.replace replaceImportRe, (match, p1) ->
        "@import '#{ pu.convertCssPath(p1, src) }'"
      styl = stylus(preprocessedStr)
        .set('filename', src)
        .set('compress', true)
#        .set 'preprocessImport', (path, srcFile) ->
#          if path.indexOf('//') < 0
#            path
#          else
#            pu.convertCssPath(path, srcFile)
        .include(@params.baseDir)
        .use(stylusLib)
      Future.call([styl, 'render'])
    .zip(Future.call(mkdirp, path.dirname(dst))).flatMap (cssStr) ->
      Future.call(fs.writeFile, dst, cssStr)
    .failAloud()

    @readyPromise.when(f)


  getWorkload: -> 1



exports.CompileStylus = CompileStylus

_ = require('underscore')
fs = require('fs')
path = require('path')
Future = require('../utils/Future')
appHelper = require('./AppHelper')
ServiceManager = require('./ServiceManager')
VendorManager = require('./VendorManager')
WidgetScanner = require('./WidgetScanner')

global.window =
  addEventListener: ->
  location: {pathname: ''}

global.document =
  createElement: -> {}
  getElementsByTagName: -> []

global.navigator = userAgent: ''

applicationGlobal =
  config:
    localFsMode: false
    debug:
      deferred: {}
      future:
        longStackTrace: {}
        trackUnhandled: {}

global.CORD_PROFILER_ENABLED = false
global.CORD_IS_BROWSER = true

findServiceContainerExpr = /\.serviceContainer\.(?:get(?:Service)?)\(\'([a-zA-Z]+)\'\)/g

_define = (dependencies, callback) ->
  if not callback
    callback = dependencies
    dependencies = []
  [dependencies, callback]


class ScannerStorage

  constructor: ->
    @data = {}


  set: (key, value, context) ->
    if not context
      @data[key] = value
    else
      @data[key][context] = value


  get: (key, context) ->
    return false if not @data[key]
    cache = @data[key]
    if context and cache[context]
      cache[context]
    else
      cache


storage = new ScannerStorage()


class Scanner

  @scan: (destination, currentDir, context) ->
    destinationInfo = appHelper.normalizePath(destination, currentDir)
    cache = storage.get(destinationInfo.dest, context)
    return cache if cache
    value = (new Scanner(destinationInfo.dest, destinationInfo.type, context)).run()
    storage.set(destinationInfo.dest, value)
    value


  constructor: (@destination, @type, @context) ->
    @context = @destination if not @context
    @currentDir = path.dirname(@destination)
    @dependencies = []
    @definition = null


  run: ->
    if @type == 'vendor'
      Future.resolved
        dependencies: VendorManager.get(@destination)
        definition: VendorManager.getDefinition(@destination)
    else
      Future.call(fs.readFile, "#{appHelper.targetDir}/public/#{@destination}.js", {encoding: 'utf8'}).then (sourceContent) =>
        @sourceContent = sourceContent.replace('define(', 'return define(')

        [dependencies, definitionCallback] = (new Function('define, global', @sourceContent))(_define, applicationGlobal)
        @resolveDependencies(dependencies, definitionCallback)
      .then =>
        _.object(['dependencies', 'definition'], [_.uniq(@dependencies), @definition])


  resolveDependencies: (dependencies, definitionCallback) ->
    promises = _.map(dependencies, (dependency) => Scanner.scan(dependency, @currentDir, @context))
    Future.all(promises).then (scanned) =>
      definitionArguments = []
      for item in scanned
        definitionArguments.push(item.definition)
        @dependencies = @dependencies.concat(item.dependencies)

      @dependencies.push(@destination)
      @definition = definitionCallback.apply(null, definitionArguments)
      storage.set(@destination, _.object(['dependencies', 'definition'], [@dependencies, @definition]), @context)
      @getServiceDependencies()
    .then =>
      (new WidgetScanner(this)).run() if @type == 'widget'


  selfScan: (destination) ->
    Scanner.scan(destination, @currentDir, @context)


  getServiceDependencies: ->
    services = @definition.inject or []
    services = _.values(services) if not _.isArray(services)
    items = []
    context = @context
    matched = (match[1] while match = findServiceContainerExpr.exec(@sourceContent))
    services = services.concat(matched)
    for service in _.uniq(services)
      items = items.concat(ServiceManager.get(service))

    if @destination == 'bundles/cord/core/services/Logger'
      # Избегаем рекурсии
      index = items.indexOf('cord!ServiceContainer')
      items.splice(index, 1) if index != -1

    promises = _.map(_.uniq(items), (dependency) -> Scanner.scan(dependency, undefined, context))
    Future.all(promises).then (scanned) =>
      @dependencies = @dependencies.concat(item.dependencies) for item in scanned
      return


module.exports = Scanner

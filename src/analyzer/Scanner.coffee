_ = require('underscore')
fs = require('fs')
path = require('path')
Future = require('../utils/Future')
appHelper = require('./AppHelper')
ServiceManager = require('./ServiceManager')
VendorManager = require('./VendorManager')
WidgetScanner = require('./WidgetScanner')


emptyCallback = () ->

global.window =
  addEventListener: ->
  location:
    pathname: ''

global.document =
  createElement: -> {}
  getElementsByTagName: -> []

global.navigator = userAgent: ''
global.CORD_PROFILER_ENABLED = false
global.CORD_IS_BROWSER = true

# поиск сервисов вызываемых через serviceContainer
findServiceContainerExpr = /\.serviceContainer\.(?:get(?:Service)?)\(\'([a-zA-Z]+)\'\)/g

# поиск динамически создаваемых виджетов
findDynamicCreatedExpr = /\.(?:insertChildWidget|initChildWidget)\((?:(?:_?this\.)([a-zA-Z]+)|(?:(?:\')([a-zA-Z\/]+)(?:\')))\,/g

# поиск создаваемых форм
findDynamicFormExpr = /widgetType\:\s\'([a-zA-Z\/]+)\'/g


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
    ###
    Получает список зависимостей класса
    @param String destination путь к классу
    @param String currentDir директория класса, инициирующего сканирование (для относительных путей)
    @param String context контекст в рамках которого идет сканирование (например: название главного виджета)
    @return Future {dependencies: Array, definition: Object}
    ###
    destinationInfo = appHelper.normalizePath(destination, currentDir)
    cache = storage.get(destinationInfo.dest, context)
    return cache if cache
    value = (new Scanner(destinationInfo.dest, destinationInfo.type, context)).run()
    storage.set(destinationInfo.dest, value)
    value


  constructor: (@destination, @type, @context) ->
    @context = @destination if not @context
    @currentDir = path.dirname(@destination)
    @currentBundle = appHelper.getBundleByRelativePath(@destination)
    @dependencies = []
    @definition = null


  run: ->
    ###
    Выполняет загрузку исходника класса и запускает выявление зависимостей
    @return Future {dependencies: Array, definition: Object}
    ###
    if @type == 'vendor'
      Future.resolved
        dependencies: VendorManager.get(@destination)
        definition: VendorManager.getDefinition(@destination)
    else
      Future.call(fs.readFile, "#{appHelper.targetDir}/public/#{@destination}.js", {encoding: 'utf8'}).then (sourceContent) =>
        # функция должна возвращать результат
        @sourceContent = sourceContent.replace('define(', 'return define(')
        [dependencies, definitionCallback] = (new Function('define, require', @sourceContent))(_define, emptyCallback)
        @resolveDependencies(dependencies, definitionCallback)
      .then =>
        _.object(['dependencies', 'definition'], [_.uniq(@dependencies), @definition])


  resolveDependencies: (dependencies, definitionCallback) ->
    ###
    Объединяет переданные зависимости с зависимостями текущего класса
    @param Array dependencies список основных зависимостей класса, объявленных в define
    @param Closure definitionCallback функция инициализации класса
    @return Future
    ###
    promises = _.map(dependencies, (dependency) => @selfScan(dependency))
    Future.all(promises).then (scanned) =>
      definitionArguments = []
      for item in scanned
        definitionArguments.push(item.definition)
        @dependencies = @dependencies.concat(item.dependencies)

      @dependencies.push(@destination)
      @definition = definitionCallback.apply(null, definitionArguments)

      # закешируем промежуточных результат, для избежания рекурсии запрашиваемых зависимостей
      storage.set(@destination, _.object(['dependencies', 'definition'], [@dependencies, @definition]), @context)

      @getContentDependencies()
    .then =>
      (new WidgetScanner(this)).run() if @type == 'widget'


  selfScan: (destination) ->
    ###
    Запускает сканирование переданного класса с параметрами текущего класса
    ###
    Scanner.scan(destination, @currentDir, @context)


  getContentDependencies: ->
    ###
    Получение всех зависиммостей найденых в теле класса
    ###
    services = @definition.inject or []
    services = _.values(services) if not Array.isArray(services)
    items = []

    # получаем сервисы
    matched = (match[1] while match = findServiceContainerExpr.exec(@sourceContent))
    services = services.concat(matched)
    items = items.concat(ServiceManager.get(service)) for service in _.uniq(services)

    # Хак для избежания рекурсии
    if @destination == 'bundles/cord/core/services/Logger'
      index = items.indexOf('cord!ServiceContainer')
      items.splice(index, 1) if index != -1

    # получаем динмаически создаваемые элементы в поведении
    if @type == 'system' and @destination != 'Behaviour' and @destination.indexOf('Behaviour') == (@destination.length - 9)
      matched = []
      while match = findDynamicCreatedExpr.exec(@sourceContent)
        if match[1] and @definition.prototype[match[1]]
          matched.push("cord-w!#{@definition.prototype[match[1]]}@/#{@currentBundle}")
        else if match[2]
          matched.push("cord-w!#{match[2]}@/#{@currentBundle}")

      if @definition.prototype.dropDownWidgetClass
        matched.push("cord-w!#{@definition.prototype.dropDownWidgetClass}@/#{@currentBundle}")

      items = items.concat(matched)

    # получаем динамически создаваемые формы
    matched = ("cord-w!#{match[1]}@/#{@currentBundle}" while match = findDynamicFormExpr.exec(@sourceContent))
    items = items.concat(matched)

    context = @context
    promises = _.map(_.uniq(items), (dependency) -> Scanner.scan(dependency, undefined, context))
    Future.all(promises).then (scanned) =>
      @dependencies = @dependencies.concat(item.dependencies) for item in scanned
      return


module.exports = Scanner

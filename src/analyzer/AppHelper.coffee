_ = require('underscore')
fs = require('fs')
path = require('path')
normalizePathSeparator = require('../utils/fsNormalizePathSeparator')
Future = require '../utils/Future'
appConfig = require '../appConfig'
requirejs = require process.cwd() + '/node_modules/requirejs'
requirejsConfig = require '../build/task/requirejs-config'

prefixTypes =
  'cord': 'system'
  'cord-w': 'widget'
  'cord-t': 'translate'
  'cord-m': 'model'
  'vendor': 'vendor'

bundleConfigs = {}

storage = {}


class AppHelper

  constructor: ->
    @_bundles = []
    @_cordPathHandlers = {}
    @_currentRequireContext = null


  initRequireJs: (@targetDir) ->
    ###
    Метода настраивает requirejs и запускает инициализацию всех необходимых зависимостей
    @param String targetDir директория скомпилированного приложения
    ###
    appConfig.getBundles(@targetDir).then (bundles) =>
      @_applicationBundles = bundles
      requirejsConfig(@targetDir)
    .then ->
      Future.require('cord!requirejs/cord-w', 'cord!requirejs/cord-m', 'cord!requirejs/cord-t')
    .then (handlers) =>
      @_requireContext = requirejs.s.contexts._
      @_cordPathHandlers = _.object(['cord-w', 'cord-m', 'cord-t'], handlers)


  fileExists: (filePath) ->
    ###
    Проверяет доступ к файлу
    @param String filePath путь к файлу
    @return Boolean
    ###
    try
      not fs.accessSync(filePath, fs.R_OK)
    catch
      false


  normalizePath: (source, context) ->
    ###
    Преобразует системный путь к файлу в относительный, с учетом расширений и некоторых особенностей ядра
    @param String path путь к файлу
    @return Object детальная информация о результате преобразования
    ###
    if source.indexOf('.') == 0 and context
      source = normalizePathSeparator(path.join(context, source))

    return storage[source] if storage[source]

    mapInfo = @_requireContext.makeModuleMap(source)

    if not mapInfo.prefix and mapInfo.name.indexOf('//') != -1
      mapInfo.prefix = 'cord-w'
      mapInfo.name = '/' + mapInfo.name if mapInfo.name.charAt(0) != '/'

    relativeFilePath = if mapInfo.prefix and @_cordPathHandlers[mapInfo.prefix]
      fullInfo = @_cordPathHandlers[mapInfo.prefix].getFullInfo(mapInfo.name)
      fullInfo.relativeFilePath
    else if @_requireContext.config.paths[mapInfo.name]
      mapInfo.prefix = 'cord'
      @_requireContext.config.paths[mapInfo.name]
    else
      mapInfo.prefix = 'vendor' if not mapInfo.prefix
      mapInfo.name

    if @getBundleByRelativePath(relativeFilePath)
      mapInfo.prefix = 'core' if mapInfo.prefix == 'vendor'
      relativeFilePath = "bundles/#{relativeFilePath}" if relativeFilePath.indexOf('bundles/') != 0

    if relativeFilePath.charAt(0) == '/'
      relativeFilePath = relativeFilePath.substr(0)

    if relativeFilePath == 'app/application'
      mapInfo.prefix = 'cord'

    storage[source] =
      dest: relativeFilePath
      type: prefixTypes[mapInfo.prefix]


  getBundles: ->
    ###
    Получение списка доступных бандлов приложения
    @return Array
    ###
    @_applicationBundles


  getBundleConfig: (bundle) ->
    ###
    Получение конфигурации для указанного бандла
    @param String bundle - название бандла
    @return Object
    ###
    if bundleConfigs[bundle] then bundleConfigs[bundle] else null


  setBundleConfig: (bundle, config) ->
    ###
    Установка конфигурации указанного бандла
    @param String bundle название бандла
    @param Object config конфигурация
    ###
    bundleConfigs[bundle] = config


  getBundleByRelativePath: (relativePath) ->
    ###
    Проверяет входит ли в переданный путь какой либо бандл приложения и возвращает его.
    @param String relativePath относительный путь к файлу
    @return String|null
    ###
    _.find(@_applicationBundles, (bundle) -> relativePath.indexOf(bundle) != -1)


module.exports = new AppHelper()

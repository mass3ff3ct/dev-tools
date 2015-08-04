_ = require('underscore')
fs = require('fs')
path = require('path')
Future = require('../utils/Future')
appHelper = require('./AppHelper')
ServiceManager = require('./ServiceManager')
VendorManager = require('./VendorManager')
Scanner = require('./Scanner')


class Analyzer

  constructor: (@targetDir) ->
    @widgets = []


  init: ->
    appHelper.initRequireJs(@targetDir).then ->
      configFilePaths = ("cord!/#{ bundle }/config" for bundle in appHelper.getBundles())
      Future.require(configFilePaths)
    .then (configs) =>
      bundles = appHelper.getBundles()
      widgets = []
      for config, index in configs
        bundle = bundles[index]
        appHelper.setBundleConfig(bundle, config)

        # Собираем все виджеты из конфига, минуя системный бандл cord/core
        for id, definition of config.routes when definition.widget and bundle != 'cord/core'
          widgets.push("cord-w!#{definition.widget}@/#{bundle}")

        ServiceManager.addItems(@_prepareDataForServiceManager(config.services)) if config.services
        VendorManager.addItems(@_prepareDataForVendorManager(config.requirejs)) if config.requirejs

      @widgets = _.uniq(widgets)


  all: ->
    ###
    Получение списка зависимостей каждого корневого виджета с последующим их сохранением в файл
    ###
    @init().then =>
      promises = (@_one(widget) for widget in @widgets)
      Future.all(promises)
    .then (groupList) =>
      # Получим пути всех конфигов, для добавления их в зависимости
      configPaths = for bundle in appHelper.getBundles()
        configPathInfo = appHelper.normalizePath("cord!/#{ bundle }/config")
        configPathInfo.dest

      groupList = _.map(groupList, (group) -> group.concat(configPaths))
      result = _.object(@widgets, groupList)

      fileName = "#{@targetDir}/analyze-result.json"
      Future.call(fs.writeFile, fileName, JSON.stringify(result, null, 2)).then ->
        console.log "create analyzed file #{fileName}"
    .catch (error) ->
      console.error error, error.stack


  one: (name) ->
    ###
    Получение списка зависимостей указанного класса с последующим их выводом в консоль
    @param String name путь до класса (например: "cord!Future@cord/core")
    ###
    @init().then =>
      @_one(name)
    .then (dependencies) =>
      console.log "Dependencies for widget #{name}:"
      console.log dependencies
    .catch (error) ->
      console.error error


  _one: (name) ->
    ###
    Private method
    Получение списка зависимостей указанного класса
    @param String name путь до класа
    @return Future
    ###
    Scanner.scan(name).then (scanned) ->
      scanned.dependencies.sort()


  _prepareDataForServiceManager: (data) ->
    ###
    Подготавливает переданные настройки для сервисов
    ###
    data = _.extend(data, data[':browser']) if data[':browser']
    delete data[':browser']
    delete data[':server']
    data


  _prepareDataForVendorManager: (data) ->
    ###
    Подготавливает переданные настройки для вендоров
    ###
    {paths, shim} = data
    shortNames = {}
    result = {}
    for id, destination of paths
      result[id] =
        destination: destination
        vendors: []
      shortNames[path.basename(destination)] = id

    for id, params of shim when params.deps
      # Иногда в shim, вместо paths, определяют вендор. Надо быть к этому готовым
      if not result[id] and id.indexOf('vendor/') == 0
        result[id] = destination: id
      else if shortNames[id]
        id = shortNames[id]
      result[id].vendors = params.deps or []

    result


module.exports = Analyzer

_ = require('underscore')
fs = require('fs')
path = require('path')
Future = require('../utils/Future')
appHelper = require('./AppHelper')

findWidgetExpr = /"(?:type|contentWidget)":\s?"([^"]+)"/g
findSwitcherVariableExpr = /\"widget\":\"\^?([a-zA-Z]+)\"/
deferredOrInlineFileExpr = /__.+\.html\.js/


class WidgetScanner

  constructor: (@scanner) ->
    @widgetName = path.basename(@scanner.destination)


  run: ->
    Future.all([
      @getBehaviourDependencies()
      @getTemplateDependencies()
    ])


  getTemplateDependencies: ->
    ###
    Получение всех зависимостей из шаблона виджета
    ###
    templateName = @widgetName.charAt(0).toLowerCase() + @widgetName.substr(1)
    templatePath = "#{@scanner.currentDir}/#{templateName}.html"
    templateFilePath = "#{appHelper.targetDir}/public/#{templatePath}.js"

    if appHelper.fileExists(templateFilePath)
      # Поиск в директории виджета дополнительных файлов шаблона (__deferred, __inline)
      filesInDir = fs.readdirSync("#{appHelper.targetDir}/public/#{@scanner.currentDir}")
      deferredOrInlineFiles = ("#{@scanner.currentDir}/#{file.replace('.js', '')}" for file in filesInDir when deferredOrInlineFileExpr.test(file))
      @scanner.dependencies = @scanner.dependencies.concat(deferredOrInlineFiles)

      Future.call(fs.readFile, templateFilePath, encoding: 'utf8').then (templateContent) =>
        switchedWidgets = []
        matched = []

        while match = findWidgetExpr.exec(templateContent)
          # если мы нашли Switcher, то попробуем найти виджеты для него
          if match[1] == 'Switcher'
            # определим переменную контекста, которая устанавливает отображение и найдем её в теле виджета
            tmp = templateContent.substring(match.index)
            switcherVariable = findSwitcherVariableExpr.exec(tmp.substring(0, tmp.indexOf('}')))
            switchedWidgets = switchedWidgets.concat(@_getSwitcherWidgets(switcherVariable[1]))
            matched.push(match[1])
          else if match[1].indexOf('/') != -1
            matched.push(match[1])

        matched = matched.concat(switchedWidgets)
        promises = _.map(_.uniq(matched), (match) => @scanner.selfScan("cord-w!#{match}@/#{@scanner.currentBundle}"))
        Future.all(promises)
      .then (scanned) =>
        dependencies = [templatePath, "#{templatePath}.struct"]
        dependencies = dependencies.concat(item.dependencies) for item in scanned
        @scanner.dependencies = @scanner.dependencies.concat(dependencies)
        return


  getBehaviourDependencies: ->
    ###
    Получение всех зависимостей из поведения виджета
    ###
    behaviourFile = "#{appHelper.targetDir}/public/#{@scanner.currentDir}/#{@widgetName}Behaviour.js"
    if @scanner.definition.prototype.behaviourClass != false and appHelper.fileExists(behaviourFile)
      @scanner.selfScan("cord!#{@scanner.currentDir}/#{@widgetName}Behaviour").then (scanned) =>
        @scanner.dependencies = @scanner.dependencies.concat(scanned.dependencies)
        return


  _getSwitcherWidgets: (variableName) ->
    ###
    Поиск виджетов для Switcher
    ###

    # Попробуем найти явные определения виджетов
    reg = new RegExp("\\'?#{variableName}\\'?\\:\\s?\\'([a-zA-z\\/]+)\\'", 'g')
    switched = (match[1] while (match = reg.exec(@scanner.sourceContent)))
    if switched.length == 0
      # или найдем в конфиге текщего бандла наш виджет и поищем в его параметрах
      config = appHelper.getBundleConfig(@scanner.currentBundle)
      for id, definition of config.routes
        widgetInfo = appHelper.normalizePath("#{definition.widget}@/#{@scanner.currentBundle}")
        params = definition.params or {}
        if widgetInfo.dest == @scanner.context and (widgetPath = (params[variableName] or params.contentWidget))
          switched.push(widgetPath)

    switched


module.exports = WidgetScanner

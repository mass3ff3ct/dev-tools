_ = require('underscore')
fs = require('fs')
path = require('path')
Future = require('../utils/Future')
appHelper = require('./AppHelper')

findWidgetExpr = /"type":\s?"([^"]+)"/g
findSwitcherVariable = /\"widget\":\"\^?([a-zA-Z]+)\"/


class WidgetScanner

  constructor: (@scanner) ->
    @widgetName = path.basename(@scanner.destination)


  run: ->
    Future.all([
      @getBehaviourDependencies()
      @getTemplateDependencies()
    ])


  getTemplateDependencies: ->
    templateName = @widgetName.charAt(0).toLowerCase() + @widgetName.substr(1)
    templateFile = "#{appHelper.targetDir}/public/#{@scanner.currentDir}/#{templateName}.html.js"
    if appHelper.fileExists(templateFile)
      Future.call(fs.readFile, templateFile, encoding: 'utf8').then (templateContent) =>
        currentBundle = appHelper.getBundleByRelativePath(@scanner.destination)
        switchedWidgets = []
        matched = while match = findWidgetExpr.exec(templateContent)
          if match[1] == 'Switcher'
            tmp = templateContent.substring(match.index)
            switcherVariable = findSwitcherVariable.exec(tmp.substring(0, tmp.indexOf('}')))
            switchedWidgets = switchedWidgets.concat(@_getSwitcherWidgets(switcherVariable[1], currentBundle))
          match[1]

        matched = matched.concat(switchedWidgets)
        promises = _.map(_.uniq(matched), (match) => @scanner.selfScan("cord-w!#{match}@/#{currentBundle}"))
        Future.all(promises)
      .then (scanned) =>
        dependencies = []
        dependencies = dependencies.concat(item.dependencies) for item in scanned
        @scanner.dependencies = @scanner.dependencies.concat(dependencies)
        return


  getBehaviourDependencies: ->
    behaviourFile = "#{appHelper.targetDir}/public/#{@scanner.currentDir}/#{@widgetName}Behaviour.js"
    if @scanner.definition.prototype.behaviourClass != false and appHelper.fileExists(behaviourFile)
      @scanner.selfScan("cord!#{@scanner.currentDir}/#{@widgetName}Behaviour").then (scanned) =>
        @scanner.dependencies = @scanner.dependencies.concat(scanned.dependencies)
        return


  _getSwitcherWidgets: (variableName, bundle) ->
    reg = new RegExp("\\'?#{variableName}\\'?\\:\\s?\\'([a-zA-z\\/]+)\\'", 'g')
    switched = (match[1] while (match = reg.exec(@scanner.sourceContent)))
    if switched.length == 0
      config = appHelper.getBundleConfig(bundle)
      for id, definition of config.routes
        widgetInfo = appHelper.normalizePath("#{definition.widget}@/#{bundle}")
        params = definition.params or {}
        if widgetInfo.dest == @scanner.context and (widgetPath = (params[variableName] or params.contentWidget))
          switched.push(widgetPath)

    switched


module.exports = WidgetScanner

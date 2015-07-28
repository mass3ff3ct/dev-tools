_ =  require('underscore')

emptyCallback = () ->

requireEmulate = (deps) -> deps

getFunctionBody = (func) ->
  text = func.toString()
  text.substring(text.indexOf("{") + 1, text.lastIndexOf("}"))

storage = {}


class ServiceManager

  constructor: ->
    @data =
      serviceContainer:
        dependencies: ['cord!ServiceContainer']
        services: []
      fallback:
        dependencies: ['cord!init/browserInit']
        services: []
      router:
        dependencies: ['cord!router/clientSideRouter']
        services: []
      config:
        dependencies: []
        services: []
      serverRequest:
        dependencies: []
        services: []


  addItems: (items) ->
    @add(id, definition) for id, definition of items


  add: (id, definition) ->
    @data[id] =
      services: definition.deps or []
      dependencies: @_findDependencies(id, definition)


  get: (id) ->
    service = @data[id]

    if not service
      console.log "Used an undefined service #{id}"
      return []

    return storage[id] if storage[id]
    dependencies = @data[id].dependencies
    dependencies = dependencies.concat(@get(serviceId)) for serviceId in service.services
    storage[id] = dependencies


  _findDependencies: (name, definition) ->
    factory = if typeof definition == 'function' then definition else definition.factory
    callback = new Function('get, done, require, CORD_IS_BROWSER', getFunctionBody(factory))
    dependencies = []

    try
      dependencies = callback(emptyCallback, emptyCallback, requireEmulate, true) or []
    catch error
      console.log "Failed initialize service callback. Service: #{name}, error: #{error}"

    dependencies


module.exports = new ServiceManager

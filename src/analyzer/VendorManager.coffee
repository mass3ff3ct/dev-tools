_ = require('underscore')

# объект - пустышка
godObject =
  prototype: {}
  makeBase: ->

storage = {}

class VendorManager

  constructor: (@manager) ->
    @data = {}


  addItems: (items) ->
    @add(id, definition) for id, definition of items


  add: (id, definition) ->
    definition.isRemote = definition.destination.indexOf('//') == 0
    @data[id] = definition


  get: (id) ->
    vendor = @data[id]

    return [id] if not vendor or vendor.isRemote
    return storage[id] if storage[id]

    dependencies = []
    dependencies = [id]
    dependencies = dependencies.concat(@get(vendorId)) for vendorId in vendor.vendors
    storage[id] = dependencies


  getDefinition: (id) ->
     switch id
      when 'underscore', 'lodash' then _
      when 'monologue', 'dustjs-helpers' then godObject
      else {}


module.exports = new VendorManager

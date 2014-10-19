// Generated by CoffeeScript 1.8.0
var BuildTask, Future, RenderIndexHtml, fs, path, pathToCore, requirejsConfig,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

fs = require('fs');

path = require('path');

Future = require('../../utils/Future');

BuildTask = require('./BuildTask');

requirejsConfig = require('./requirejs-config');

pathToCore = 'bundles/cord/core';

RenderIndexHtml = (function(_super) {
  __extends(RenderIndexHtml, _super);

  function RenderIndexHtml() {
    return RenderIndexHtml.__super__.constructor.apply(this, arguments);
  }


  /*
  Renders and saves given widget (came from -I --index CLI option) as main index.html page.
  This is need mainly for mobile apps (phonegap) working in SPA mode.
   */

  RenderIndexHtml.prototype.run = function() {
    var config, dst, nodeInit;
    dst = "" + this.params.targetDir + "/public/index.html";
    nodeInit = require(path.join(this.params.targetDir, 'public', pathToCore, 'init/nodeInit'));
    config = nodeInit.loadConfig(this.params.info.configName);
    global.appConfig = config;
    global.config = config.node;
    global.CORD_PROFILER_ENABLED = config.node.debug.profiler.enable;
    return requirejsConfig(this.params.targetDir).then(function() {
      return Future.require('cord!utils/DomInfo', 'cord!ServiceContainer', 'cord!WidgetRepo');
    }).then((function(_this) {
      return function(DomInfo, ServiceContainer, WidgetRepo) {
        var container, widgetRepo;
        container = new ServiceContainer;
        container.set('container', container);
        widgetRepo = new WidgetRepo;
        widgetRepo.setServiceContainer(container);
        return widgetRepo.createWidget(_this.params.file).then(function(rootWidget) {
          rootWidget._isExtended = true;
          widgetRepo.setRootWidget(rootWidget);
          return rootWidget.show({}, DomInfo.fake());
        });
      };
    })(this)).then(function(out) {
      return Future.call(fs.writeFile, dst, out);
    }).link(this.readyPromise);
  };

  return RenderIndexHtml;

})(BuildTask);

module.exports = RenderIndexHtml;
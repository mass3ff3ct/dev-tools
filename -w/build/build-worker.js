// Generated by CoffeeScript 1.8.0

/*
Build worker process main script.
 */
var BuildWorker, CompileCoffeeScript, CompileStylus, CompileWidgetTemplate, CopyFile, Fake, RenderIndexHtml, util, worker, _;

util = require('util');

_ = require('underscore');

CompileCoffeeScript = require('./task/CompileCoffeeScript');

CompileStylus = require('./task/CompileStylus');

CompileWidgetTemplate = require('./task/CompileWidgetTemplate');

Fake = require('./task/Fake');

CopyFile = require('./task/CopyFile');

RenderIndexHtml = require('./task/RenderIndexHtml');

BuildWorker = (function() {
  BuildWorker.prototype.tasks = null;

  function BuildWorker() {
    this.tasks = {};
  }

  BuildWorker.prototype.addTask = function(taskParams) {

    /*
    Registers and launches new task based on the given params
    @param Object taskParams
    @return Future[Nothing]
     */
    var TaskClass, task;
    TaskClass = this._chooseTask(taskParams);
    task = this.tasks[taskParams.id] = new TaskClass(taskParams);
    task.run();
    util.log(">>> " + taskParams.file + "...");
    return task.ready()["finally"]((function(_this) {
      return function() {
        return delete _this.tasks[taskParams.id];
      };
    })(this));
  };

  BuildWorker.prototype._chooseTask = function(taskParams) {

    /*
    Selects task class by task params
    @return Class
     */
    var info;
    info = taskParams.info;
    if (info.isCoffee) {
      return CompileCoffeeScript;
    } else if (info.isStylus) {
      return CompileStylus;
    } else if (info.isWidgetTemplate) {
      return CompileWidgetTemplate;
    } else if (info.isIndexPage) {
      return RenderIndexHtml;
    } else if (info.ext === '.orig' || info.ext.substr(-1) === '~') {
      return Fake;
    } else {
      return CopyFile;
    }
  };

  return BuildWorker;

})();

worker = new BuildWorker;

process.on('message', function(task) {
  return worker.addTask(task).done(function() {
    return process.send({
      type: 'completed',
      task: task.id
    });
  }).fail(function(err) {
    if (err.constructor.name !== 'ExpectedError') {
      console.error(err.stack, err);
    } else {
      err = err.underlyingError;
    }
    return process.send({
      type: 'failed',
      task: task.id,
      error: err
    });
  });
});

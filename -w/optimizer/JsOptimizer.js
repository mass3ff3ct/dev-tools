// Generated by CoffeeScript 1.8.0
var ByWidgetGroupDetector, CorrelationGroupDetector, Future, GroupRepo, HeuristicGroupDetector, JsOptimizer, UglifyJS, coffeeUtilCode, fs, requirejsConfig, sha1, _;

fs = require('fs');

_ = require('underscore');

UglifyJS = require('uglify-js');

Future = require('../utils/Future');

sha1 = require('sha1');

ByWidgetGroupDetector = require('./ByWidgetGroupDetector');

CorrelationGroupDetector = require('./CorrelationGroupDetector');

GroupRepo = require('./GroupRepo');

HeuristicGroupDetector = require('./HeuristicGroupDetector');

requirejsConfig = require('./requirejsConfig');

coffeeUtilCode = ['__hasProp = {}.hasOwnProperty', '__extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; }', '__bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }', '__slice = [].slice', '__indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; }'];

JsOptimizer = (function() {

  /*
  Build optimizer.
  * grouping modules into single files
  * minifying, gzipping
  * and so on
   */
  JsOptimizer.prototype._zDir = null;

  JsOptimizer.prototype._requireConfig = null;

  function JsOptimizer(params, zDirFuture) {
    this.params = params;
    this.zDirFuture = zDirFuture;
    this._zDir = "" + this.params.targetDir + "/public/assets/z";
  }

  JsOptimizer.prototype.run = function() {
    var predefinedPromise, statFile, statPromise;
    this._requireConfig = requirejsConfig.collect(this.params.targetDir);
    statFile = 'require-stat.json';
    statPromise = Future.call(fs.readFile, statFile)["catch"](function() {
      console.warn("Error reading require-stat file '" + statFile + "'. Going to group only by widget...");
      return '{}';
    }).then((function(_this) {
      return function(data) {
        return JSON.parse(data);
      };
    })(this));
    predefinedPromise = Future.require("" + this.params.targetDir + "/optimizer-predefined-groups")["catch"](function(err) {
      console.warn("Error reading predefined-groups file: " + err + "!");
      return {};
    });
    return Future.all([statPromise, predefinedPromise]).spread((function(_this) {
      return function(stat, predefinedGroupsInfo) {
        console.log("Calculating JS group optimization...");
        return _this._generateOptimizationMap(stat, predefinedGroupsInfo);
      };
    })(this)).then((function(_this) {
      return function(groupMap) {
        return _this._generateOptimizedFiles(groupMap);
      };
    })(this))["catch"](function(e) {
      console.warn("JS group optimization failed! Reason: " + e + ". Skipping...", e.stack);
      return {};
    });
  };

  JsOptimizer.prototype._generateOptimizationMap = function(stat, predefinedGroupsInfo) {

    /*
    Analizes collected requirejs stats and tryes to group modules together in optimized way.
    @param Map[String -> Array[String]] stat collected statistics of required files per page
    @return Map[String -> Array[String]]
     */
    var groupRepo, iterations, widgetDetector;
    iterations = 1;
    groupRepo = new GroupRepo;
    this._createPredefinedGroups(predefinedGroupsInfo, groupRepo);
    this._removePredefinedGroupsFromStat(stat, predefinedGroupsInfo);
    this._removeBrowserInitFromStat(stat);
    widgetDetector = new ByWidgetGroupDetector(groupRepo, this.params.targetDir);
    return widgetDetector.process(stat).then(function(stat) {
      var corrDetector, group, groupId, groups, heuristicDetector, page, resultMap, _i, _len, _ref;
      while (iterations--) {
        console.log("100% correlation JS group detection...");
        corrDetector = new CorrelationGroupDetector(groupRepo);
        stat = corrDetector.process(stat);
        console.log("Heuristic JS group detection...");
        heuristicDetector = new HeuristicGroupDetector(groupRepo);
        stat = heuristicDetector.process(stat);
      }
      resultMap = {};
      for (page in stat) {
        groups = stat[page];
        for (_i = 0, _len = groups.length; _i < _len; _i++) {
          groupId = groups[_i];
          group = groupRepo.getGroup(groupId);
          if (group) {
            resultMap[groupId] = _.uniq(group.getModules());
          }
          if (group) {
            groupRepo.removeGroupDeep(groupId);
          }
        }
      }
      _ref = groupRepo.getGroups();
      for (groupId in _ref) {
        group = _ref[groupId];
        if (!group.isSubGroup()) {
          resultMap[groupId] = _.uniq(group.getModules());
        }
      }
      return resultMap;
    });
  };

  JsOptimizer.prototype._createPredefinedGroups = function(predefinedGroupsInfo, groupRepo) {

    /*
    Registers predefined groups in group repository
     */
    var groupId, modules, name;
    for (name in predefinedGroupsInfo) {
      modules = predefinedGroupsInfo[name];
      groupId = 'predefined-' + sha1(modules.sort().join()) + '-' + name;
      groupRepo.createGroup(groupId, modules);
    }
  };

  JsOptimizer.prototype._removePredefinedGroupsFromStat = function(stat, predefinedGroupsInfo) {

    /*
    Removes modules of predefined groups from the stat to avoid mixing them up with another groups
     */
    var m, modules, name, page, removeModules, _i, _len;
    removeModules = [];
    for (name in predefinedGroupsInfo) {
      modules = predefinedGroupsInfo[name];
      for (_i = 0, _len = modules.length; _i < _len; _i++) {
        m = modules[_i];
        removeModules.push(m);
      }
    }
    for (page in stat) {
      modules = stat[page];
      stat[page] = _.difference(modules, removeModules);
    }
  };

  JsOptimizer.prototype._removeBrowserInitFromStat = function(stat) {

    /*
    Removes browser-init script occurences from stat as it never included in any group
     */
    var modules, page;
    for (page in stat) {
      modules = stat[page];
      if (modules[0].indexOf('bundles/cord/core/init/browser-init') !== -1) {
        modules.shift();
      }
    }
  };

  JsOptimizer.prototype._generateOptimizedFiles = function(groupMap) {

    /*
    Generates and saves optimized module group and configuration files
    @param Map[String -> Array[String]] groupMap optimized group map
    @return Future
     */
    return this._requireConfig.then((function(_this) {
      return function(requireConf) {
        console.log("Merging JS group files...");
        return _this._mergeGroups(groupMap, requireConf);
      };
    })(this));
  };

  JsOptimizer.prototype._mergeGroups = function(groupMap, requireConf) {

    /*
    Launches merge for all optimized groups.
    Returns converted group map with group names replaced with generated merged file names
    @param Map[String -> Array[String]] groupMap source group map
    @param Object requireConf requirejs configuration object
    @return Future[Map[String -> Array[String]]
     */
    var groupId, mergePromises, modules, resultMap;
    resultMap = {};
    mergePromises = (function() {
      var _results;
      _results = [];
      for (groupId in groupMap) {
        modules = groupMap[groupId];
        _results.push(this._mergeGroup(this._reorderShimModules(modules, requireConf.shim), requireConf).spread(function(fileName, existingModules) {
          resultMap[fileName] = existingModules;
        }));
      }
      return _results;
    }).call(this);
    return Future.all(mergePromises).then(function() {
      return resultMap;
    });
  };

  JsOptimizer.prototype._mergeGroup = function(modules, requireConf) {

    /*
    Merges the given modules list into one big optimized file. Order of the modules is preserved.
    Returns future with optimized file name.
    @param Array[String] modules list of group modules
    @param Object requireConf requirejs configuration object
    @return Future[String]
     */
    var contentArr, csUtilHit, existingModules, futures, j, module, removePromises, savePromise;
    existingModules = [];
    contentArr = [];
    csUtilHit = {};
    removePromises = [];
    futures = (function() {
      var _i, _len, _results;
      _results = [];
      for (j = _i = 0, _len = modules.length; _i < _len; j = ++_i) {
        module = modules[j];
        _results.push((function(_this) {
          return function(module, j) {
            var moduleFile;
            moduleFile = requireConf.paths[module] ? "" + _this.params.targetDir + "/public/" + requireConf.paths[module] + ".js" : "" + _this.params.targetDir + "/public/" + module + ".js";
            return Future.call(fs.readFile, moduleFile, 'utf8').then(function(origJs) {
              var code, definePresent, deps, i, js, shim, _j, _len1;
              if (_this.params.removeSources) {
                removePromises.push(Future.call(fs.unlink, moduleFile));
              }
              js = origJs.replace('define([', "define('" + module + "',[").replace('define( [', "define('" + module + "',[").replace('define(function()', "define('" + module + "',function()").replace('define(factory)', "define('" + module + "',factory)");
              definePresent = js !== origJs || js.indexOf('define.amd') > -1;
              for (i = _j = 0, _len1 = coffeeUtilCode.length; _j < _len1; i = ++_j) {
                code = coffeeUtilCode[i];
                if (js.indexOf(code) > -1) {
                  js = js.replace(code + ",\n  ", '');
                  js = js.replace(code, '');
                  csUtilHit[i] = true;
                }
              }
              js = js.replace("var ;\n", '');
              if ((shim = requireConf.shim[module]) && (shim.exports != null) && _.isString(shim.exports)) {
                deps = _.isArray(shim.deps) && shim.deps.length > 0 ? "['" + (shim.deps.join("','")) + "'], " : '';
                js += "\ndefine('" + module + "', " + deps + (_this._generateShimExportsFn(shim)) + ");\n";
              } else if (!definePresent) {
                js += "\ndefine('" + module + "', function(){});\n";
              }
              contentArr[j] = js;
              existingModules.push(module);
              return true;
            })["catch"](function() {
              return false;
            });
          };
        })(this)(module, j));
      }
      return _results;
    }).call(this);
    savePromise = Future.all([Future.all(futures), this.zDirFuture]).then((function(_this) {
      return function() {
        var fileName, hit, i, mergedContent, resultCode;
        resultCode = '';
        hit = Object.keys(csUtilHit);
        if (hit.length > 0) {
          resultCode += 'var ' + ((function() {
            var _i, _len, _results;
            _results = [];
            for (_i = 0, _len = hit.length; _i < _len; _i++) {
              i = hit[_i];
              _results.push(coffeeUtilCode[i]);
            }
            return _results;
          })()).join(',\n  ') + ';\n\n';
        }
        mergedContent = resultCode + contentArr.join("\n\n");
        if (_this.params.jsMinify) {
          mergedContent = UglifyJS.minify(mergedContent, {
            fromString: true,
            mangle: true
          }).code;
        }
        fileName = sha1(mergedContent);
        console.log("Saving " + fileName + ".js ...");
        return Future.call(fs.writeFile, "" + _this._zDir + "/" + fileName + ".js", mergedContent).then(function() {
          return [fileName, existingModules];
        });
      };
    })(this));
    return Future.all([savePromise, Future.all(removePromises)]).spread(function(savePromiseResult) {
      return savePromiseResult;
    }).failAloud('JsOptimizer::_mergeGroup');
  };

  JsOptimizer.prototype._generateShimExportsFn = function(shimConfig) {

    /*
    Generates special function code for shim-module definition. Stolen from the requirejs sources.
    @param Object shimConfig shim configuration for the module
    @return String
     */
    return '(function (global) {\n' +
    '    return function () {\n' +
    '        var ret, fn;\n' +
    (shimConfig.init ?
            ('       fn = ' + shimConfig.init.toString() + ';\n' +
            '        ret = fn.apply(global, arguments);\n') : '') +
    (shimConfig.exports ?
            '        return ret || global.' + shimConfig.exports + ';\n' :
            '        return ret;\n') +
    '    };\n' +
    '}(this))';
  };

  JsOptimizer.prototype._reorderShimModules = function(modules, requirejsShim) {

    /*
    Reorders the given list of modules according to their dependency tree from the shim configuration.
    Order of modules that are not present in shim configuration is leaved untouch. Shim modules are placed in the end.
    In the result array the module A which depends on module B comes after module B.
    @param Array[String] modules source module list
    @param Object requirejsShim shim configuration part of requirejs configuration config object
    @return Array[String]
     */
    var depInfo, depModule, depOrder, deps, i, info, max, module, orderInfo, orderUnresolved, resultModules, shimModules, unresolved, _i, _j, _k, _len, _len1, _name, _ref, _ref1;
    orderInfo = {};
    for (module in requirejsShim) {
      info = requirejsShim[module];
      if ((info.deps != null) && info.deps.length > 0) {
        orderInfo[module] = {};
        _ref = info.deps;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          depModule = _ref[_i];
          if (requirejsShim[depModule] != null) {
            orderInfo[module][depModule] = false;
          } else {
            orderInfo[depModule] = 0;
            orderInfo[module][depModule] = false;
          }
        }
      } else {
        orderInfo[module] = 0;
      }
    }
    while (true) {
      orderUnresolved = false;
      for (module in orderInfo) {
        deps = orderInfo[module];
        if (_.isObject(deps)) {
          unresolved = false;
          for (depModule in deps) {
            depInfo = deps[depModule];
            if (depInfo === false) {
              if (!_.isObject(orderInfo[depModule])) {
                deps[depModule] = orderInfo[depModule] + 1;
              } else {
                unresolved = true;
              }
            }
          }
          if (!unresolved) {
            max = 0;
            for (depModule in deps) {
              depOrder = deps[depModule];
              if (depOrder > max) {
                max = depOrder;
              }
            }
            orderInfo[module] = max;
          } else {
            orderUnresolved = true;
          }
        }
      }
      if (!orderUnresolved) {
        break;
      }
    }
    shimModules = {};
    resultModules = [];
    for (_j = 0, _len1 = modules.length; _j < _len1; _j++) {
      module = modules[_j];
      if (orderInfo[module] != null) {
        if (shimModules[_name = orderInfo[module]] == null) {
          shimModules[_name] = [];
        }
        shimModules[orderInfo[module]].push(module);
      } else {
        resultModules.push(module);
      }
    }
    if (Object.keys(shimModules).length > 0) {
      for (i = _k = 0, _ref1 = _.max(Object.keys(shimModules)); 0 <= _ref1 ? _k <= _ref1 : _k >= _ref1; i = 0 <= _ref1 ? ++_k : --_k) {
        if (shimModules[i] != null) {
          resultModules = resultModules.concat(shimModules[i]);
        }
      }
    }
    return resultModules;
  };

  return JsOptimizer;

})();

module.exports = JsOptimizer;

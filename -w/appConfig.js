// Generated by CoffeeScript 1.8.0
var Future, appConfFile, path, requirejs, savedBundlesPromise;

path = require('path');

requirejs = require(process.cwd() + '/node_modules/requirejs');

Future = require('./utils/Future');

appConfFile = 'app/application';

savedBundlesPromise = null;

exports.getBundles = function(targetDir) {

  /*
  Loads application config and returns list of bundles of the application including core bundle.
  @param String targetDir directory with compiled cordjs project
  @return Future[Array[String]]
   */
  if (savedBundlesPromise) {
    return savedBundlesPromise;
  } else {
    requirejs.config({
      baseUrl: path.join(targetDir, 'public')
    });
    savedBundlesPromise = Future.require(appConfFile).then(function(bundles) {
      return ['cord/core'].concat(bundles);
    });
    return savedBundlesPromise;
  }
};

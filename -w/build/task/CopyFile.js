// Generated by CoffeeScript 1.8.0
var BuildTask, CopyFile, fs, mkdirp, path,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

fs = require('fs');

path = require('path');

mkdirp = require('mkdirp');

BuildTask = require('./BuildTask');

CopyFile = (function(_super) {
  __extends(CopyFile, _super);

  function CopyFile() {
    return CopyFile.__super__.constructor.apply(this, arguments);
  }

  CopyFile.prototype.run = function() {
    var dst, src;
    src = "" + this.params.baseDir + "/" + this.params.file;
    dst = "" + this.params.targetDir + "/" + this.params.file;
    return mkdirp(path.dirname(dst), (function(_this) {
      return function(err) {
        var r;
        if (err) {
          throw err;
        }
        r = fs.createReadStream(src);
        r.pipe(fs.createWriteStream(dst));
        return r.on('end', function() {
          return _this.readyPromise.resolve();
        });
      };
    })(this));
  };

  return CopyFile;

})(BuildTask);

module.exports = CopyFile;

// Generated by CoffeeScript 1.3.3
(function() {
  var CoffeeStand, Compiler, EventEmitter, Walker, Watcher, colors, cp, fs, minimatch, path, _,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  fs = require('fs');

  path = require('path');

  cp = require('child_process');

  EventEmitter = require('events').EventEmitter;

  _ = require('underscore');

  minimatch = require('minimatch');

  colors = require('colors');

  Walker = require('./walker');

  Watcher = require('./watcher');

  Compiler = require('./compiler');

  module.exports = CoffeeStand = (function(_super) {

    __extends(CoffeeStand, _super);

    function CoffeeStand(root, opts) {
      var _ref, _ref1, _ref10, _ref2, _ref3, _ref4, _ref5, _ref6, _ref7, _ref8, _ref9;
      this.root = root != null ? root : process.cwd();
      this.opts = opts != null ? opts : {};
      this.root = path.resolve(this.root);
      this.nolint = (_ref = this.opts.nolint) != null ? _ref : false;
      this.nojs = (_ref1 = this.opts.nojs) != null ? _ref1 : false;
      this.nolog = (_ref2 = this.opts.nolog) != null ? _ref2 : true;
      this.lintConfigPath = (_ref3 = this.opts.lintConfigPath) != null ? _ref3 : path.join(this.root, '.coffeelint');
      this.dirs = [];
      this.files = [];
      this.errorFiles = [];
      this.watchers = {};
      this.compilers = {};
      this.lintConfig = {
        nolint: this.nolint
      };
      this.ignoreFile = (_ref4 = (_ref5 = this.opts) != null ? _ref5.ignoreFile : void 0) != null ? _ref4 : '.csignore';
      this.mapperFile = (_ref6 = (_ref7 = this.opts) != null ? _ref7.mapperFile : void 0) != null ? _ref6 : '.csmapper';
      this.ignoreFiles = ['**/.*', '**/node_modules'];
      if (((_ref8 = this.opts) != null ? _ref8.ignorePatterns : void 0) != null) {
        this.setIgnoreFiles(this.opts.ignorePatterns);
      }
      this.mapper = (_ref9 = (_ref10 = this.opts) != null ? _ref10.mapper : void 0) != null ? _ref9 : {};
    }

    CoffeeStand.prototype._isIgnore = function(file) {
      var v, _i, _len, _ref;
      _ref = this.ignoreFiles;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        v = _ref[_i];
        if (minimatch(file, v)) {
          return true;
        }
      }
      return false;
    };

    CoffeeStand.prototype._readCSMapper = function(p, cb) {
      var _this = this;
      if (p == null) {
        p = ".csmapper";
      }
      if (!(p != null) || typeof p === 'function') {
        cb = p;
        p = ".csignore";
      }
      p = path.resolve(p);
      return fs.readFile(p, 'utf8', function(err, body) {
        var newmapper;
        if (!err) {
          try {
            newmapper = JSON.parse(body);
            _this.mapper = _.extend(_this.mapper, newmapper);
          } catch (e) {
            console.log(e);
          }
        }
        return cb(_this.mapper);
      });
    };

    CoffeeStand.prototype._readCSIgnore = function(p, cb) {
      var _this = this;
      if (p == null) {
        p = ".csignore";
      }
      if (!(p != null) || typeof p === 'function') {
        cb = p;
        p = ".csignore";
      }
      p = path.resolve(p);
      return fs.readFile(p, 'utf8', function(err, body) {
        var patterns;
        if (!err) {
          patterns = _(body.split('\n')).chain().compact().value();
          _this.setIgnoreFiles(patterns);
        }
        return cb(_this.ignoreFiles);
      });
    };

    CoffeeStand.prototype._addDir = function(dir) {
      return this.dirs.push(dir);
    };

    CoffeeStand.prototype._addFile = function(file) {
      return this.files.push(file);
    };

    CoffeeStand.prototype._rmDir = function(dir) {
      return this.dirs = _(this.dirs).without(dir);
    };

    CoffeeStand.prototype._rmFile = function(file) {
      return this.files = _(this.files).without(file);
    };

    CoffeeStand.prototype._removeCompiler = function(file) {
      var _ref;
      if ((_ref = this.compilers[file]) != null) {
        _ref.removeAllListeners();
      }
      return delete this.compilers[file];
    };

    CoffeeStand.prototype._parseLint = function(lint) {
      var error, errorCount, errors, lcolor, v, warnCount, _i, _len;
      errorCount = 0;
      warnCount = 0;
      if (lint.err) {
        return {
          message: ("\n  lint compile error: " + lint.err).red,
          errorCount: errorCount
        };
      } else if (lint.length === 0) {
        return {
          message: "",
          errorCount: errorCount
        };
      } else {
        errors = [];
        for (_i = 0, _len = lint.length; _i < _len; _i++) {
          v = lint[_i];
          if (v.level === 'error') {
            errorCount += 1;
            lcolor = 'red';
          } else if (v.level === 'warn') {
            lcolor = 'yellow';
            warnCount += 1;
          }
          error = [("  #" + v.lineNumber + " " + v.message + ".")[lcolor]];
          if (v.context != null) {
            error.push((" " + v.context + ".")[lcolor]);
          }
          error.push((" (" + v.rule + ")").grey);
          if (v.line) {
            error.push(("\n    => " + v.line).grey);
          }
          errors.push(error.join(''));
        }
        errors.push("  CoffeeLint: ".grey + ("" + errorCount + " errors").red + (" " + warnCount + " warnings").yellow);
        return {
          message: '\n' + errors.join('\n'),
          errorCount: errorCount
        };
      }
    };

    CoffeeStand.prototype._setCompiler = function(filename) {
      var _this = this;
      this.compilers[filename] = new Compiler(filename, this.lintConfig, this.mapper);
      this.compilers[filename].on('compiled', function(data) {
        var message;
        if (!_this.nolog) {
          message = ['compiled'.green, " - " + data.file];
          if (!_this.nojs) {
            message.push((" => " + data.jsfile).grey);
          }
          if (!_this.nolint) {
            message.push(_this._parseLint(data.lint).message);
          }
          console.log(message.join('') + '\n');
        }
        return _this.emit('compiled', data);
      });
      this.compilers[filename].on('nofile', function(data) {
        if (!_this.nolog) {
          console.log('coffee file not found'.yellow + (" - " + data.file + "\n"));
        }
        return _this.emit('nofile', data);
      });
      this.compilers[filename].on('write error', function(data) {
        var message;
        if (!_this.nolog) {
          message = ['fail to write js file'.yellow, " - " + data.file, " -> " + data.jsfile];
          console.log(message.join(''), '\n');
        }
        return _this.emit('write error', data);
      });
      this.compilers[filename].on('compile error', function(data) {
        if (!_this.nolog) {
          console.log('compile error'.red + (" in " + data.file) + (" => " + data.err).red + '\n');
        }
        _this.errorFiles.push(data.file);
        _this.errorFiles = _(_this.errorFiles).uniq();
        return _this.emit('compile error', data);
      });
      return this.compilers[filename].compile(this.nojs);
    };

    CoffeeStand.prototype._closeWatcher = function(dir) {
      var _ref, _ref1;
      if ((_ref = this.watchers[dir]) != null) {
        _ref.removeAllListeners();
      }
      if ((_ref1 = this.watchers[dir]) != null) {
        _ref1.close();
      }
      return delete this.watchers[dir];
    };

    CoffeeStand.prototype._watch = function(dirname, cb) {
      var _this = this;
      this.watchers[dirname] = new Watcher(dirname);
      this.watchers[dirname].on('dir removed', function(filename) {
        if (!_this._isIgnore(filename)) {
          _this.emit('dir removed', filename);
          return _this.stopWatch(filename);
        }
      });
      this.watchers[dirname].on('dir created', function(filename) {
        if (!_this._isIgnore(filename)) {
          _this.startWatch(filename);
          return _this.emit('dir created', filename);
        }
      });
      this.watchers[dirname].on('file created', function(filename) {
        if (path.extname(filename) === '.coffee' && !_this._isIgnore(filename)) {
          _this.startCompiler(filename);
          return _this.emit('coffee created', filename);
        }
      });
      this.watchers[dirname].on('file changed', function(filename, stats) {
        var _ref;
        if (path.extname(filename) === '.coffee' && !_this._isIgnore(filename)) {
          _this.emit('coffee changed', filename);
          return (_ref = _this.compilers[filename]) != null ? typeof _ref.compile === "function" ? _ref.compile() : void 0 : void 0;
        }
      });
      this.watchers[dirname].on('file removed', function(filename) {
        var rmfn, _ref, _ref1, _ref2;
        if (path.extname(filename) === '.coffee' && !_this._isIgnore(filename)) {
          if ((((_ref = _this.compilers[filename]) != null ? _ref.jsname : void 0) != null) && ((_ref1 = _this.compilers[filename]) != null ? _ref1.rmJS : void 0)) {
            rmfn = (_ref2 = _this.compilers[filename]) != null ? _ref2.rmJS : void 0;
          } else {
            rmfn = function(cb) {
              return cb();
            };
          }
          return rmfn(function() {
            _this.errorFiles = _(_this.errorFiles).without(filename);
            _this.stopCompiler(filename);
            return _this.emit('coffee removed', filename);
          });
        }
      });
      this.watchers[dirname].on('watchstart', function() {
        return _this.emit('watchstart', dirname);
      });
      return this.watchers[dirname].watch(cb);
    };

    CoffeeStand.prototype.getLintConfig = function(p, cb) {
      var _this = this;
      if (p == null) {
        p = this.lintConfigPath;
      }
      if (typeof p === 'function') {
        cb = p;
        p = this.lintConfigPath;
      }
      if (this.nolint === true) {
        this.lintConfig = {
          nolint: false
        };
        return typeof cb === "function" ? cb() : void 0;
      } else {
        return fs.readFile(p, 'utf8', function(err, body) {
          if (!err) {
            try {
              _this.lintConfig = JSON.parse(body);
              _this.lintConfig.nolint = false;
            } catch (e) {

            }
          }
          return typeof cb === "function" ? cb(_this.lintConfig) : void 0;
        });
      }
    };

    CoffeeStand.prototype.getErrorFiles = function() {
      return this.errorFiles;
    };

    CoffeeStand.prototype.setIgnoreFiles = function(newFiles) {
      return this.ignoreFiles = _(this.ignoreFiles).union(newFiles);
    };

    CoffeeStand.prototype.unsetIgnoreFiles = function(patterns) {
      if (patterns != null) {
        this.ignoreFiles = _(this.ignoreFiles).reject(function(v) {
          return patterns.indexOf(v) !== -1;
        });
      }
      return this.ignoreFiles;
    };

    CoffeeStand.prototype.startCompiler = function(file) {
      this._addFile(file);
      return this._setCompiler(file);
    };

    CoffeeStand.prototype.startWatch = function(dir, cb) {
      this._addDir(dir);
      return this._watch(dir, cb);
    };

    CoffeeStand.prototype.stopCompiler = function(file) {
      this._removeCompiler(file);
      return this._rmFile(file);
    };

    CoffeeStand.prototype.stopWatch = function(dir) {
      this.unsetIgnoreFiles(dir);
      this._closeWatcher(dir);
      return this._rmDir(dir);
    };

    CoffeeStand.prototype.kill = function(cb) {
      var v, _i, _j, _len, _len1, _ref, _ref1;
      _ref = this.dirs;
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        v = _ref[_i];
        this.stopWatch(v);
      }
      _ref1 = this.files;
      for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
        v = _ref1[_j];
        this.stopCompiler(v);
      }
      return typeof cb === "function" ? cb() : void 0;
    };

    CoffeeStand.prototype.walk = function(file_cb, dir_cb) {
      var ignore, walker,
        _this = this;
      ignore = this.ignoreFiles;
      walker = new Walker(this.root, {
        ignoreFiles: ignore,
        callbacks: {
          dir: function(dir, stat) {
            return typeof file_cb === "function" ? file_cb(dir, stat) : void 0;
          },
          file: function(file, stat) {
            return typeof dir_cb === "function" ? dir_cb(file, stat) : void 0;
          }
        }
      });
      return walker.walk(function(ret) {
        return _this.emit('walkend', ret);
      });
    };

    CoffeeStand.prototype.run = function() {
      var _this = this;
      return this.getLintConfig(function() {
        return _this._readCSIgnore(_this.ignoreFile, function() {
          return _this._readCSMapper(_this.mapperFile, function() {
            return _this.walk(function(dir, stat) {
              return _this.startWatch(dir);
            }, function(file, stat) {
              if (path.extname(file) === '.coffee') {
                return _this.startCompiler(file);
              }
            });
          });
        });
      });
    };

    return CoffeeStand;

  })(EventEmitter);

}).call(this);
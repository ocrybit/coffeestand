// Generated by CoffeeScript 1.3.3
(function() {
  var Compiler, EventEmitter, coffee, coffeelint, fs, minimatch, path, util,
    __hasProp = {}.hasOwnProperty,
    __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

  util = require('util');

  fs = require('fs');

  path = require('path');

  EventEmitter = require('events').EventEmitter;

  coffee = require('coffee-script');

  coffeelint = require('coffeelint');

  minimatch = require('minimatch');

  module.exports = Compiler = (function(_super) {

    __extends(Compiler, _super);

    function Compiler(csfile, lintConfig, mapper) {
      this.csfile = csfile;
      this.lintConfig = lintConfig != null ? lintConfig : {};
      this.mapper = mapper;
      if (this.csfile) {
        this.jsfile = this._getJSPath(this.csfile, this.mapper);
      }
    }

    Compiler.prototype._replaceExt = function(txt, ext) {
      if (ext == null) {
        ext = 'js';
      }
      return txt.replace(/\.coffee$/, "." + ext);
    };

    Compiler.prototype._getJSPath = function(csfile, mapper) {
      var basename, dirname, filebase, k, m, v;
      filebase = path.basename(csfile);
      dirname = path.dirname(csfile);
      basename = path.basename(dirname);
      if (typeof mapper === 'object' && !util.isArray(mapper)) {
        for (k in mapper) {
          v = mapper[k];
          try {
            m = minimatch(csfile, k);
            if (m) {
              if (util.isArray(v)) {
                return this._replaceExt(path.normalize(csfile.replace(v[0], v[1])));
              } else if (typeof v === 'function') {
                return this._replaceExt(path.normalize(v(csfile)));
              }
            }
          } catch (e) {

          }
        }
      }
      return ("" + dirname + "/") + this._replaceExt(filebase);
    };

    Compiler.prototype._emitCompiled = function(lint) {
      return this.emit('compiled', {
        file: this.csfile,
        jsfile: this.jsfile,
        lint: lint
      });
    };

    Compiler.prototype._emitWriteError = function(err, lint) {
      return this.emit('write error', {
        file: this.csfile,
        jsfile: this.jsfile,
        err: err,
        lint: lint
      });
    };

    Compiler.prototype._emitter = function(lint, writeErr) {
      if (writeErr) {
        return this._emitWriteError(writeErr, lint);
      } else {
        return this._emitCompiled(lint);
      }
    };

    Compiler.prototype._writeJS = function(compiled, lint, nojs) {
      var version,
        _this = this;
      if (nojs) {
        return this._emitter(lint, null);
      } else {
        version = '// Generated by CoffeeScript ' + coffee.VERSION;
        return fs.writeFile(this.jsfile, [version, compiled].join('\n'), function(err) {
          return _this._emitter(lint, err);
        });
      }
    };

    Compiler.prototype._coffeeLint = function(code) {
      var lint;
      if (this.lintConfig.nolint) {
        lint = false;
      } else {
        try {
          lint = coffeelint.lint(code, this.lintConfig);
        } catch (e) {
          lint = {
            err: e
          };
        }
      }
      return lint;
    };

    Compiler.prototype._getCode = function(cb) {
      var _this = this;
      return fs.readFile(this.csfile, 'utf8', function(err, code) {
        return cb({
          err: err,
          code: code,
          file: _this.csfile
        });
      });
    };

    Compiler.prototype.rmJS = function(cb) {
      var _this = this;
      return fs.unlink(this.jsfile, function(err) {
        if (err) {
          _this.emit('unlink error', {
            file: _this.csfile,
            jsfile: _this.jsfile,
            err: err
          });
        } else {
          _this.emit('js removed', {
            file: _this.csfile
          });
        }
        return typeof cb === "function" ? cb() : void 0;
      });
    };

    Compiler.prototype.compile = function(nojs) {
      var _this = this;
      if (nojs == null) {
        nojs = false;
      }
      return this._getCode(function(data) {
        var compiled, lint;
        if (data.err) {
          return _this.emit('nofile', {
            file: _this.csfile,
            err: data.err
          });
        } else {
          try {
            compiled = coffee.compile(data.code);
            lint = _this._coffeeLint(data.code);
            return _this._writeJS(compiled, lint, nojs);
          } catch (e) {
            return _this.emit('compile error', {
              file: _this.csfile,
              err: e
            });
          }
        }
      });
    };

    return Compiler;

  })(EventEmitter);

}).call(this);
fs = require('fs')
path = require('path')

async = require('async')
rimraf = require('rimraf')
mkdirp = require('mkdirp')
chai = require('chai')
should = chai.should()

Compiler = require('../lib/compiler')

describe('Watcher', ->
  GOOD_CODE = 'foo = 1'
  BAD_CODE = 'foo ==== 1'
  TMP = "#{__dirname}/tmp"
  FOO = "#{TMP}/foo"
  FOO2 = "#{TMP}/foo2"
  NODIR = "#{TMP}/nodir"
  NOFILE = "#{TMP}/nofile.coffee"
  HOTCOFFEE = "#{TMP}/hot.coffee"
  BLACKCOFFEE = "#{TMP}/black.coffee"
  ICEDCOFFEE = "#{FOO}/iced.coffee"
  TMP_BASE = path.basename(TMP)
  FOO_BASE = path.basename(FOO)
  FOO2_BASE = path.basename(FOO2)
  NODIR_BASE = path.basename(NODIR)
  NOFILE_BASE = path.basename(NOFILE)
  HOTCOFFEE_BASE = path.basename(HOTCOFFEE)
  BLACKCOFFEE_BASE = path.basename(BLACKCOFFEE)
  ICEDCOFFEE_BASE = path.basename(ICEDCOFFEE)
  compiler = new Compiler()
  stats = {}

  beforeEach((done) ->
    mkdirp(FOO, (err) ->
      async.forEach(
        [HOTCOFFEE, ICEDCOFFEE],
        (v, callback) ->
          fs.writeFile(v, GOOD_CODE, (err) ->
            async.forEach(
              [FOO, HOTCOFFEE,ICEDCOFFEE,BLACKCOFFEE],
              (v, callback2) ->
                fs.stat(v, (err,stat) ->
                  stats[v] = stat
                  callback2()
                )
              ->
                callback()
            )
          )
        ->
          compiler = new Compiler(HOTCOFFEE)
          done()
      )
    )
  )

  afterEach((done) ->
    rimraf(TMP, (err) =>
      compiler.removeAllListeners()
      done()
    )
  )

  describe('constructor', ->
    it('init test', ->
      Compiler.should.be.a('function')
    )
    it('should instanciate', ->
      compiler.should.be.a('object')
    )
  )

  describe('_replaceExt', ->
    it('replace the file extension', ->
      compiler._replaceExt(HOTCOFFEE, 'js')
        .should.equal(path.dirname(HOTCOFFEE) + '/hot.js')
    )
  )

  describe('_getJSPath', ->
    it('make a JS file path from @csfile path', (done) ->
      compiler._getJSPath(ICEDCOFFEE).should.equal("#{FOO}/iced.js")
      compiler._getJSPath(ICEDCOFFEE, {'**/foo/*': [/\/foo\//, '/foo3/']})
        .should.equal("#{TMP}/foo3/iced.js")
      compiler._getJSPath(ICEDCOFFEE, {'**/foo/*': (v) ->
        return "#{TMP}/foo4/../foo3/iced.coffee"
      }).should.equal("#{TMP}/foo3/iced.js")
      done()
    )
  )
  describe('_emitCompiled', ->
    it('emit "compiled" event', (done) ->
      compiler.on('compiled', (data) ->
        data.lint.should.be.ok
        done()
      )
      compiler._emitCompiled(true)
    )
  )
  describe('_emitWriteError', ->
    it('emit "write error" event', (done) ->
      compiler.on('write error', (data) ->
        data.err.should.be.ok
        done()
      )
      compiler._emitWriteError(true, false)
    )
  
  )
  describe('_emitter', ->
    it('emit "compiled" event with writeErr', (done) ->
      compiler.on('compiled', (data) ->
        data.lint.should.be.ok
        done()
      )
      compiler._emitter(true, false)
    )
    it('emit "write error" with writeErr', (done) ->
      compiler.on('write error', (data) ->
        data.err.should.be.ok
        done()
      )
      compiler._emitter(true, true)
    )
  )

  describe('_writeJS',()->
    it('should emit "compiled" if successfully write',(done)->
      compiler.once('compiled',(data)=>
        data.jsfile.should.be.equal(compiler.jsfile)
        done()
      )
      compiler._writeJS('')
    )
    it('should emit "compiled" if nojs is set true',(done)->
      compiler.once('compiled',(data)=>
        data.jsfile.should.be.equal(compiler.jsfile)
        done()
      )
      compiler._writeJS('', [], true)
    )
    it('should emit "write error" if failed to write for some reason',(done)->
      compiler = new Compiler(NODIR + '/foo.coffee')
      compiler.jsname = NODIR
      compiler.once('write error',(data)=>
        data.jsfile.should.be.equal("#{NODIR}/foo.js")
        done()
      )
      compiler._writeJS('')
    )
  )

  describe('_coffeeLint', ->
    it('abort linting and return false if @lintConfig.nolint is true', () ->
      compiler = new Compiler(TMP, {nolint: true})
      compiler._coffeeLint(GOOD_CODE).should.not.ok
    )
    it('return an empty array for a good code', ->
      compiler._coffeeLint(GOOD_CODE).should.be.empty.instanceOf(Array)
    )
    it('return a not-empty array for a bad code', ->
      compiler._coffeeLint(BAD_CODE).should.not.be.empty
      compiler._coffeeLint(BAD_CODE).should.be.instanceOf(Array)
    )
  )

  describe('_getCode', ->
    it('should read coffee file', (done) ->
      compiler._getCode((data) ->
        should.not.exist(data.err)
        data.code.should.equal(GOOD_CODE)
        done()
      )
    )
  )

  describe('rmJS', ->
    it('remove the destination JS file', (done) ->
      fs.writeFile(compiler.jsfile, '', ->
        fs.stat(compiler.jsfile, (err,stats) ->
          should.exist(stats)
          compiler.rmJS(->
            fs.stat(compiler.jsfile, (err,stats) ->
              should.not.exist(stats)
              done()
            )
          )
        )
      )
    )
  )

  describe('compile', ->
    it('should emit "nofile" if @csfile is not found', (done) ->
      compiler = new Compiler(NOFILE)
      compiler.once('nofile',(data)=>
        data.err.code.should.be.equal('ENOENT')
        done()
      )
      compiler.compile()
    )
    it('should emit "compile error" for bad code', (done) ->
      fs.writeFile(BLACKCOFFEE, BAD_CODE, =>
        compiler = new Compiler(BLACKCOFFEE)
        compiler.once('compile error',(data)=>
          data.file.should.equal(BLACKCOFFEE)
          done()
        )
        compiler.compile()
      )
    )
    it('should emit "compiled" and write to @jsfile for good code',(done)->
      compiler.once('compiled', (data) =>
        data.file.should.be.equal(HOTCOFFEE)
        fs.exists(compiler.jsfile, (exist) =>
          exist.should.be.ok
          done()
        )
      )
      compiler.compile()
    )

  )

)
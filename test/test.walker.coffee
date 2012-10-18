fs = require('fs')
path = require('path')

async = require('async')
rimraf = require('rimraf')
mkdirp = require('mkdirp')
chai = require('chai')
should = chai.should()
Walker = require('../lib/walker')

describe('Walker', () ->
  TMP = "#{__dirname}/tmp"
  FOO = "#{TMP}/foo"
  FOO2 = "#{TMP}/foo2"
  HOTCOFFEE = "#{TMP}/hot.coffee"
  BLACKCOFFEE = "#{TMP}/black.coffee"
  ICEDCOFFEE = "#{FOO}/iced.coffee"
  TMP_BASE = path.basename(TMP)
  FOO_BASE = path.basename(FOO)
  FOO2_BASE = path.basename(FOO2)
  HOTCOFFEE_BASE = path.basename(HOTCOFFEE)
  BLACKCOFFEE_BASE = path.basename(BLACKCOFFEE)
  ICEDCOFFEE_BASE = path.basename(ICEDCOFFEE)
  walker = new Walker()
  stats = {}

  beforeEach((done) ->
    mkdirp(FOO, (err) ->
      async.forEach(
        [HOTCOFFEE, ICEDCOFFEE],
        (v, callback) ->
          fs.writeFile(v, '', (err) ->
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
          walker = new Walker(TMP)
          done()
      )
    )
  )

  afterEach((done) ->
    rimraf(TMP, (err) =>
      walker.removeAllListeners()
      done()
    )
  )

  describe('constructor', () ->
    it('init test', () ->
      Walker.should.be.a('function')
    )
    it('should instanciate', () ->
      walker.should.be.a('object')
    )
    it('@root should be cwd when not defined', () ->
      walker = new Walker()
      walker.root.should.equal(process.cwd())
    )
  )

  describe('_isIgnore', () ->
    it("check if a directory should be ignored", () ->
      walker = new Walker(
        TMP,
        {
          ignoreFiles : [
            '**/foo',
            '**/foo2',
            '**/hoo*',
            "#{TMP}/my.coffee"
          ]
        }
      )
      truthys = ['foo', 'hoo2', '/dir/foo2', "#{TMP}/my.coffee"]
      falsey = ['foo3', 'fool', 'my.coffee']
      for v in truthys
        walker._isIgnore(v).should.be.ok
      for v in falsey
        walker._isIgnore(v).should.not.be.ok
    )
  )

  describe('_end', () ->
    it("emit 'end' event", (done) ->
      walker.once('end', () ->
        done()
      )
      walker._end()
    )
    it("call cb with a dir list and file list", (done) ->
      walker._end((data) ->
        data.files.should.be.instanceOf(Array)
        data.dirs.should.be.instanceOf(Array)
        done()
      )
    )
  )

  describe('_readEnd', ()->
    it('substruct 1 from @readCount', () ->
      walker.readCount = 2
      walker._readEnd()
      walker.readCount.should.equal(1)
    )
    it('call @_end when @readCount is 0', (done) ->
      walker.readCount = 1
      walker.once('end', () ->
        walker.readCount.should.equal(0)
        done()
      )
      walker._readEnd()
    )
  )

  describe('_reportDir', ()->
    it('emit "dir" event, returning dir and stat', (done) ->
      walker.on('dir', (dir, stat) ->
        dir.should.equal(FOO)
        stat.should.equal(stats[FOO])
        done()
      )
      walker._reportDir(FOO, stats[FOO])
    )
    it('add dir to @dirs', (done) ->
      walker.on('dir', (dir, stat) ->
        walker.dirs.should.include(FOO)
        done()
      )
      walker._reportDir(FOO, stats[FOO])
    )
  )

  describe('_reportFile', ()->
    it('emit "file" event, returning dir and stat', (done) ->
      walker.on('file', (file, stat) ->
        file.should.equal(HOTCOFFEE)
        stat.should.equal(stats[HOTCOFFEE])
        done()
      )
      walker._reportFile(HOTCOFFEE, stats[HOTCOFFEE])
    )
    it('add dir to @files', (done) ->
      walker.on('file', (file, stat) ->
        walker.files.should.include(HOTCOFFEE)
        done()
      )
      walker._reportFile(HOTCOFFEE, stats[HOTCOFFEE])
    )
  )

  describe('_readdir', () ->
    it('read a dir and list up files and dirs found in it', (done) ->
      walker._readdir(TMP, (data) ->
        data.dirs.should.eql([FOO])
        data.files.should.eql([HOTCOFFEE])
        done()
      )
    )
  )

  describe('walk',() ->
    it('return a list of files and directories when finish walking', (done) ->
      walker.walk((data) ->
        data.dirs.should.eql([TMP, FOO])
        data.files.should.eql([HOTCOFFEE, ICEDCOFFEE])
        done()
      )
    )
    it('dir list should be all directories',(done)->
      walker.walk((data) ->
        async.forEach(
          data.dirs,
          (v, callback) ->
            fs.stat(v, (err, stat) ->
              stat.isDirectory.should.be.ok
              callback()
            )
          (v)->
            done()
        )
      )
    )
    it('file list should be all files',(done)->
      walker.walk((data) ->
        async.forEach(
          data.files,
          (v,callback)=>
            fs.stat(v,(err,stat)->
              stat.isFile.should.be.ok
              callback()
            )
          (v)->
            done()
        )
      )
    )
    it('execute dir & file cb funcs when provided', (done) ->
      file_counter = 0
      dir_counter = 0
      walker = new Walker(
        TMP,
        {
          callbacks: {
            dir:
              (dir, stat) =>
                dir.should.be.a('string')
                file_counter += 1
            file:
              (file, stat) =>
                file.should.be.a('string')
                dir_counter += 1
          }
        }
      )
      walker.walk((data) =>
        dir_counter.should.equal(data.dirs.length)
        file_counter.should.equal(data.files.length)
        dir_counter.should.equal(2)
        file_counter.should.equal(2)
        done()
      )
    )
    it('ignore dirs when @ignoreFiles is provided', (done) ->
      walker = new Walker(
        TMP,
        {
          ignoreFiles: ['**/foo']
        }
      )
      walker.walk((data) =>
        data.dirs.should.not.include(FOO)
        done()
      )
    )
  )
)
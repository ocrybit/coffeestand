fs = require('fs')
path = require('path')

async = require('async')
rimraf = require('rimraf')
mkdirp = require('mkdirp')
chai = require('chai')
should = chai.should()

Watcher = require('../lib/watcher')

describe('Watcher', ->
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
  watcher = new Watcher()
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
          watcher = new Watcher(TMP)
          done()
      )
    )
  )

  afterEach((done) ->
    rimraf(TMP, (err) ->
      watcher.removeAllListeners()
      done()
    )
  )

  describe('constructor', ->
    it('init test', ->
      Watcher.should.be.a('function')
    )
    it('should instanciate', ->
      watcher.should.be.a('object')
    )
  )

  describe('_checkMtime', ->
    it('return true is stats.mtime is the same', (done) ->
      watcher.dirs[HOTCOFFEE_BASE] = stats[HOTCOFFEE]
      watcher._checkMtime(HOTCOFFEE_BASE, stats[HOTCOFFEE]).should.be.ok
      fs.utimes(HOTCOFFEE, Date.now(), Date.now(), ->
        fs.stat(HOTCOFFEE, (err,stats) ->
          watcher._checkMtime(HOTCOFFEE_BASE, stats[HOTCOFFEE]).should.not.be.ok
          done()
        )
      )
    )
  )

  describe('_getType', ->
    it('return a file type', ->
      watcher._getType(stats[HOTCOFFEE]).should.equal('file')
      watcher._getType(stats[FOO]).should.equal('dir')
    )
  )

  describe('_getAction', ->
    it('specify the action taken on a file', (done) ->
      watcher._getAction(
        'rename',
        HOTCOFFEE_BASE,
        stats[HOTCOFFEE]
      ).should.equal('created')
      watcher.dirs[HOTCOFFEE_BASE] = stats[HOTCOFFEE]
      watcher._getAction(
        'change',
        HOTCOFFEE_BASE,
        stats[HOTCOFFEE]
      ).should.equal('unchanged')
      fs.utimes(HOTCOFFEE, Date.now(), Date.now(), ->
        fs.stat(HOTCOFFEE, (err,stats) ->
          watcher._getAction(
            'change',
            HOTCOFFEE_BASE,
            stats[HOTCOFFEE]
          ).should.equal('changed')
          watcher._getAction(
            'rename',
            HOTCOFFEE_BASE,
            null
          ).should.equal('removed')
          done()
        )
      )
    )
  )

  describe('_readdir', ->
    it('set @dirs map', (done) ->
      watcher._readdir( =>
        should.exist(watcher.dirs[FOO_BASE])
        done()
      )
    )
  )

  describe('watch', ->
    it('emit "dir created" event', (done) ->
      watcher.once('dir created', (dir) ->
        dir.should.equal(FOO2)
        done()
      )
      watcher.watch( ->
        fs.mkdir(FOO2)
      )
    )
    it('emit "file created" event', (done) ->
      watcher.once('file created', (file) ->
        file.should.be.equal(BLACKCOFFEE)
        done()
      )
      watcher.watch( ->
        fs.writeFile(BLACKCOFFEE, '')
      )
    )
    it('emit "dir removed" event', (done) ->
      watcher.once('dir removed', (dir) ->
        dir.should.equal(FOO)
        done()
      )
      watcher.watch( ->
        rimraf(FOO, ->)
      )
    )
    it('should emit "file removed" event',(done)->
      watcher.once('file removed', (file) ->
        file.should.equal(HOTCOFFEE)
        done()
      )
      watcher.watch( ->
        fs.unlink(HOTCOFFEE, ->)
      )
    )
    it('should emit "file changed" event', (done) ->
      watcher.once('file changed', (file) ->
        file.should.equal(HOTCOFFEE)
        done()
      )
      watcher.watch( ->
        fs.utimes(HOTCOFFEE, Date.now(), Date.now())
      )
    )
    it('emit "watchstart" event', (done) ->
      watcher.once('watchstart', (dir) ->
        dir.should.equal(TMP)
        done()
      )
      watcher.watch()
    )
  )
  describe('close', ->
    it("shouldn't emit after close", (done) ->
      watcher.once('dir removed', (dir) ->
        true.should.not.ok
        done()
      )
      watcher.watch( ->
        watcher.close()
        rimraf(FOO, ->
          true.should.ok
          done()
        )
      )
    )
  )
)
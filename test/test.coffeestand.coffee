fs = require('fs')
path = require('path')

async = require('async')
_ = require('underscore')
rimraf = require('rimraf')
mkdirp = require('mkdirp')
chai = require('chai')
should = chai.should()

CoffeeStand = require('../lib/coffeestand')

describe('CoffeeStand', ->
  GOOD_CODE = 'foo = 1'
  BAD_CODE = 'foo ==== 1'
  TMP = "#{__dirname}/tmp"
  FOO = "#{TMP}/foo"
  FOO2 = "#{TMP}/foo2"
  NODIR = "#{TMP}/nodir"
  NOFILE = "#{TMP}/nofile.coffee"
  HOTCOFFEE = "#{TMP}/hot.coffee"
  BLACKCOFFEE = "#{TMP}/black.coffee"
  LINTJSON = "#{TMP}/.coffeelint"
  AMERICANCOFFEE = "#{FOO2}/american.coffee"
  ICEDCOFFEE = "#{FOO}/iced.coffee"
  TMP_BASE = path.basename(TMP)
  FOO_BASE = path.basename(FOO)
  FOO2_BASE = path.basename(FOO2)
  NODIR_BASE = path.basename(NODIR)
  NOFILE_BASE = path.basename(NOFILE)
  HOTCOFFEE_BASE = path.basename(HOTCOFFEE)
  BLACKCOFFEE_BASE = path.basename(BLACKCOFFEE)
  ICEDCOFFEE_BASE = path.basename(ICEDCOFFEE)
  IGNORE_PATTERNS = ["**/foo", "**/black.coffee"]
  MAPPER_RURES = {'**/src/**' : [/\/src\//, '/lib/']}
  CSIGNORE = "#{TMP}/.csignore"
  CSMAPPER = "#{TMP}/.csmapper"
  DEFAULT_IGNOREFILES = ['**/.*', '**/node_modules']
  LINT_CONFIG = {"no_tabs" : {"level" : "error"}}
  coffeestand = new CoffeeStand()
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
          coffeestand = new CoffeeStand(TMP)
          done()
      )
    )
  )

  afterEach((done) ->
    rimraf(TMP, (err) ->
      coffeestand.removeAllListeners()
      done()
    )
  )

  describe('#constructor', ->
    it('init test', ->
      CoffeeStand.should.be.a('function')
    )
    it('should instanciate', ->
      coffeestand.should.be.a('object')
      
    )
    describe('@root', ->
      it('should be cwd when not defined', ->
        coffeestand = new CoffeeStand()
        coffeestand.root.should.equal(process.cwd())
      )
    )
  )

  describe('_isIgnore', () ->
    it("check if a directory should be ignored", () ->
      coffeestand = new CoffeeStand(
        TMP,
        {
          ignorePatterns : ['**/foo', '**/foo2', '**/hoo*', "#{TMP}/my.coffee"]
        }
      )
      truthys = ['foo', 'hoo2', '/dir/foo2', "#{TMP}/my.coffee"]
      falsey = ['foo3', 'fool', 'my.coffee']
      for v in truthys
        coffeestand._isIgnore(v).should.be.ok
      for v in falsey
        coffeestand._isIgnore(v).should.not.be.ok
    )
  )

  describe('setIgnoreFiles', ->
    it('add to ignoreDirs', ->
      coffeestand.setIgnoreFiles(IGNORE_PATTERNS)
      coffeestand.ignoreFiles
        .should.be.eql(_.union(DEFAULT_IGNOREFILES, IGNORE_PATTERNS))
    )
  )

  describe('_readCSIgnore', ->
    it('read ignore patterns from .csignore(default) file',(done)->
      fs.writeFile(CSIGNORE, IGNORE_PATTERNS.join('\n'), (err) ->
        coffeestand._readCSIgnore(CSIGNORE, ()=>
          coffeestand.ignoreFiles
            .should.eql(_.union(DEFAULT_IGNOREFILES, IGNORE_PATTERNS))
          done()
        )
      )
    )
  )

  describe('unsetIgnoreFiles', ->
    it('unset ignore patterns', () ->
      coffeestand.unsetIgnoreFiles(DEFAULT_IGNOREFILES)
      coffeestand.ignoreFiles.should.be.empty
    )
  )

  describe('_readCSMapper', ->
    it('read mapper rules from .csmapper(default) file',(done)->
      fs.writeFile(CSMAPPER, JSON.stringify(MAPPER_RURES), (err) ->
        coffeestand._readCSMapper(CSMAPPER, ()=>
          coffeestand.mapper.should.eql(MAPPER_RURES)
          done()
        )
      )
    )
  )

  describe('_addDir', ->
    it('add dir to @dirs list', ->
      coffeestand._addDir(FOO)
      coffeestand.dirs.should.include(FOO)
    )
  )

  describe('_rmDir', ->
    it('remove dir from @dirs list', ->
      coffeestand._addDir(FOO)
      coffeestand.dirs.should.include(FOO)
      coffeestand._rmDir(FOO)
      coffeestand.dirs.should.not.include(FOO)
    )
  )

  describe('_addFile', ->
    it('add file to @files list', ->
      coffeestand._addDir(HOTCOFFEE)
      coffeestand.dirs.should.include(HOTCOFFEE)
    )
  )

  describe('_rmFile', ->
    it('rmove file from @files list', ->
      coffeestand._addDir(HOTCOFFEE)
      coffeestand.dirs.should.include(HOTCOFFEE)
      coffeestand._rmDir(HOTCOFFEE)
      coffeestand.dirs.should.not.include(HOTCOFFEE)
    )
  )

  describe('walk', ->
    it('emit "walkend" with @files & @dirs when finish', (done) ->
      coffeestand.walk()
      coffeestand.once('walkend',(data)->
        data.dirs.should.eql([TMP,FOO])
        data.files.should.eql([HOTCOFFEE,ICEDCOFFEE])
        done()
      )
    )
  )

  describe('_watch', ->
    it('emit "watchstart" event', (done) ->
      coffeestand.once('watchstart', (dir)->
        dir.should.equal(TMP)
        done()
      )
      coffeestand._watch(TMP)
    )
    it('watch dir for dir creation', (done) ->
      coffeestand._watch(TMP, ->
        coffeestand.once('dir created', (dir) ->
          dir.should.equal(FOO2)
          done()
        )
        fs.mkdir(FOO2)
      )
    )
    it('watch dir for dir removal', (done) ->
      coffeestand._watch(TMP, ->
        coffeestand.once('dir removed', (dir) ->
          dir.should.equal(FOO)
          done()
        )
        rimraf(FOO, ->)
      )
    )
    it('watch dir for coffee file creation', (done) ->
      coffeestand._watch(TMP, ->
        coffeestand.once('coffee created', (file) ->
          file.should.equal(BLACKCOFFEE)
          done()
        )
        fs.writeFile(BLACKCOFFEE,GOOD_CODE)
      )
    )
    it('watch dir for coffee file removal', (done) ->
      coffeestand._watch(TMP, ->
        coffeestand.once('coffee removed', (file) ->
          file.should.equal(HOTCOFFEE)
          done()
        )
        fs.unlink(HOTCOFFEE)
      )
    )
    it('watch dir for coffee file change', (done) ->
      coffeestand._watch(TMP, ->
        coffeestand.once('coffee changed', (file) ->
          file.should.equal(HOTCOFFEE)
          done()
        )
        fs.utimes(HOTCOFFEE, Date.now(), Date.now())
      )
    )
  )

  describe('_closeWatcher', ->
    it("shouldn't watch dir after close", (done) ->
      coffeestand._watch(TMP, ->
        coffeestand.once('coffee changed', (file) ->
          file.should.equal(HOTCOFFEE)
          coffeestand.once('coffee removed', (file) ->
            false.should.be.ok
            done()
          )
          coffeestand._closeWatcher(TMP)
          fs.unlink(HOTCOFFEE)
          setTimeout(
            ()->
              true.should.be.ok
              done()
            0
          )
        )
        fs.utimes(HOTCOFFEE, Date.now(), Date.now())
      )
    )
  )


  describe('_setCompiler', ->
    it('watch and emit "compiled" for coffee files', (done) ->
      coffeestand.once('compiled', (data) ->
        data.file.should.equal(HOTCOFFEE)
        done()
      )
      coffeestand._setCompiler(HOTCOFFEE)
    )

    it('watch and emit "compiled error" for coffee files', (done) ->
      fs.writeFile(BLACKCOFFEE, BAD_CODE, (err) ->
        coffeestand.once('compile error', (data) ->
          data.file.should.equal(BLACKCOFFEE)
          done()
        )
        coffeestand._setCompiler(BLACKCOFFEE)
      )
    )

    it('emit "nofile" if no coffee files', (done) ->
      coffeestand.once('nofile', (data) ->
        data.file.should.equal(NOFILE)
        done()
      )
      coffeestand._setCompiler(NOFILE)
    )

  )

  describe('startCompiler', ->
    it('should emit "complied" & add file to @files', (done) ->
      coffeestand.once('compiled', (data) ->
        data.file.should.equal(HOTCOFFEE)
        coffeestand.files.should.include(HOTCOFFEE)
        done()
      )
      coffeestand.startCompiler(HOTCOFFEE)
    )
  )

  describe('_removeCompiler', ->
    it("shouldn't have compiler after remove", (done) ->
      coffeestand.once('compiled', (data) ->
        should.exist(coffeestand.compilers[HOTCOFFEE])
        coffeestand._removeCompiler(HOTCOFFEE)
        should.not.exist(coffeestand.compilers[HOTCOFFEE])
        done()
      )
      coffeestand._setCompiler(HOTCOFFEE)
    )
  )

  describe('stopCompiler', ->
    it("shouldn't have compiler after stop", (done) ->
      coffeestand.once('compiled', (data) ->
        should.exist(coffeestand.compilers[HOTCOFFEE])
        coffeestand.stopCompiler(HOTCOFFEE)
        should.not.exist(coffeestand.compilers[HOTCOFFEE])
        done()
      )
      coffeestand.startCompiler(HOTCOFFEE)
    )
  )

  describe('startWatch', ->
    it('should emit "coffee created" event', (done) ->
      coffeestand.startWatch(TMP, ->
        coffeestand.once('coffee created', (file) ->
          file.should.equal(BLACKCOFFEE)
          done()
        )
        fs.writeFile(BLACKCOFFEE, GOOD_CODE)
      )
    )
  )

  describe('stopWatch', ->
    it("shouldn't watch newly added coffee file after stop", (done) ->
      coffeestand.startWatch(TMP, ->
        coffeestand.once('coffee removed', (file) ->
          file.should.equal(HOTCOFFEE)
          coffeestand.once('coffee created', (file) ->
            false.should.be.ok
            done()
          )
          coffeestand.stopWatch(TMP)
          fs.writeFile(BLACKCOFFEE, GOOD_CODE)
          setTimeout(
            ()->
              true.should.be.ok
              done()
            0
          )

        )
        fs.unlink(HOTCOFFEE)
      )
    )
  )

  describe('#run', ->
    it('should watch a newly created sub directory', (done) ->
      coffeestand.once('walkend', (data)->
        coffeestand.on('watchstart', (file) ->
          if file is FOO2
            coffeestand.once('coffee created', (file) ->
              done()
            )
            fs.writeFile(AMERICANCOFFEE, GOOD_CODE)
        )
        fs.mkdir(FOO2)
      )
      coffeestand.run()
    )
  )

  describe('#kill', ->
    it('kill @compilers and @watchers, empty @dirs and @files', (done) ->
      coffeestand.on('watchstart', (dir) ->
        if dir is FOO
          coffeestand.kill(->
            coffeestand.dirs.should.be.empty
            coffeestand.files.should.be.empty
            coffeestand.compilers.should.be.empty
            coffeestand.watchers.should.be.empty
            done()
          )
      )
      coffeestand.run()
    )
  )
  describe('getErrorFiles', ->
    it('return a list of compile error files', (done) ->
      coffeestand.on('watchstart', (dir) ->
        if dir is TMP
          coffeestand.removeAllListeners()
          coffeestand.once('compile error', (data) ->
            coffeestand.getErrorFiles().should.include(BLACKCOFFEE)
            done()
          )
          fs.writeFile(BLACKCOFFEE, BAD_CODE)
      )
      coffeestand.run()
    )
  )
  describe('getLintConfig', ->
    it('read lint config file at @root.lintConfigPath(default)', (done) ->
      fs.writeFile(LINTJSON, JSON.stringify(LINT_CONFIG), (err) ->
        coffeestand.getLintConfig(LINTJSON, (config) ->
          done()
        )
      )
    )
  )
  describe('_parseLint', ->
    it('parse CoffeeLint result object', () ->
      parsed = coffeestand._parseLint([{level : "error", message: "error!"}])
      parsed.errorCount.should.equal(1)
    )
  )
)

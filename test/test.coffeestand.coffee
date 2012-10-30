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

  describe('_addFile', ->
    it('add file to @files list', ->
      coffeestand._addFile(HOTCOFFEE)
      coffeestand.files.should.include(HOTCOFFEE)
    )
  )

  describe('_rmFile', ->
    it('rmove file from @files list', ->
      coffeestand._addFile(HOTCOFFEE)
      coffeestand.files.should.include(HOTCOFFEE)
      coffeestand._rmFile(HOTCOFFEE)
      coffeestand.files.should.not.include(HOTCOFFEE)
    )
  )

  describe('watch', ->
    it('watch dir for coffee file creation', (done) ->
      coffeestand.once('watchset', (dirname)->
        coffeestand.once('coffee created', (file) ->
          file.should.equal(BLACKCOFFEE)
          done()
        )
        fs.writeFile(BLACKCOFFEE,GOOD_CODE)
      )
      coffeestand.watch()
    )
    it('watch dir for coffee file removal', (done) ->
      coffeestand.once('watchset', (dirname)->
        coffeestand.once('coffee removed', (file) ->
          file.should.equal(HOTCOFFEE)
          done()
        )
        fs.unlink(HOTCOFFEE)
      )
      coffeestand.watch()
    )
    it('watch dir for coffee file change', (done) ->
      coffeestand.once('watchset', (dirname)->
        coffeestand.once('coffee changed', (file) ->
          file.should.equal(HOTCOFFEE)
          done()
        )
        fs.utimes(HOTCOFFEE, Date.now(), Date.now())
      )
      coffeestand.watch()
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

  describe('#run', ->
    it('should watch a newly created sub directory', (done) ->
      coffeestand.once('watchset', (data)->
        coffeestand.on('watchset', (file) ->
          if file is FOO2
            coffeestand.once('compiled', (file) ->
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
      coffeestand.once('watchset', () ->
        coffeestand.kill(->
          coffeestand.files.should.be.empty
          coffeestand.compilers.should.be.empty
          done()
        )
      )
      coffeestand.run()
    )
  )
  describe('getErrorFiles', ->
    it('return a list of compile error files', (done) ->
      coffeestand.on('watchset', (dir) ->
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

  describe('_isDocco', ->
    it('return @doccoSources if filepath matches', () ->
      coffeestand.doccoSources = [TMP+'/*']
      should.exist(coffeestand._isDocco(HOTCOFFEE))
      coffeestand._isDocco(HOTCOFFEE).should.eql([TMP+'/*'])
      
    )
  )
  describe('_withoutFile', ->
    it('take off a file from @doccoFiles', () ->
      coffeestand.doccoFiles = [HOTCOFFEE, ICEDCOFFEE]
      coffeestand._withoutFile(HOTCOFFEE)
      coffeestand.doccoFiles.should.not.include(HOTCOFFEE)
    )
  )

  describe('_setDocco', ->
    it('set a child process for docco operations', () ->
      delete coffeestand.cp_docco
      should.not.exist(coffeestand.cp_docco)
      coffeestand._setDocco()
      should.exist(coffeestand.cp_docco)
      coffeestand.cp_docco.should.be.a('object')
    )
  )
  
  describe('_setDoccoSources', ->
    it('resolve and set sources for docco', () ->
      coffeestand._setDoccoSources(["#{FOO}/*"])
      console.log(coffeestand.doccoSources)
      coffeestand.doccoSources.should.include("#{FOO}/*")
    )
  )
  describe('document', ->
    it('generate docco documents', (done) ->
      coffeestand._setDoccoSources(["#{FOO}/*"])
      coffeestand.doccoOptions = {output:"#{TMP}/docs"}
      coffeestand.once('docco', ()->
        fs.exists("#{TMP}/docs/iced.html", (exist) ->
          exist.should.be.ok
          done()
        )
      )
      coffeestand.document()
    )
  )

  describe('docco', ->
    it("shouldn't proceed when @doccoFiles.length isn't 0", (done) ->
      @timeout(5000)
      coffeestand._setDoccoSources(["#{FOO}/*"])
      coffeestand.doccoFiles.push(ICEDCOFFEE)
      coffeestand.doccoOptions = {output:"#{TMP}/docs"}
      coffeestand.once('docco', (ICEDCOFFEE)->
          false.should.be.ok
      )
      coffeestand.docco(ICEDCOFFEE)
      setTimeout(
        ->
          done()
        1000
      )
    )
  )
)

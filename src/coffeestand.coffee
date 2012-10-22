# * Recursively watch directories and recompile when coffee files are changed
# * Write compiled code to a destination js file, of course  
# * Aware of newly created files and directories too!
#   So you don't have to rewatch every time you add a file
# * [Coffeelint](http://www.coffeelint.org/) the source code after every compilation
# * Ignore Files through glob matching option and .csingore files  
# * Auto-generate [docco](http://jashkenas.github.com/docco/) documents after every compilation

# ### Require Dependencies

# #### Standard Node Modules
# `fs` : [File System](http://nodejs.org/api/fs.html)  
# `path` : [Path](http://nodejs.org/api/path.html)  
# `child_process` : [Child Processes](http://nodejs.org/api/child_process.html)  
# `events` : [Events](http://nodejs.org/api/events.html)  
fs = require('fs')
path = require('path')
cp = require('child_process')
EventEmitter = require('events').EventEmitter

# #### Third Party Modules
# `underscore` by [DocumentCloud@documentcloud](https://github.com/documentcloud/underscore)  
# `minimatch` by [Isaac Z. Schlueter@issacs](https://github.com/issacs/minimatch)  
# `colors` by [Marak@marak](https://github.com/marak/colors)  
# `fswatchr` by [Tomo I/O@tomoio](https://github.com/tomoio/fswatchr)

_ = require('underscore')
minimatch = require('minimatch')
colors = require('colors')
FSWatchr = require('fswatchr')

# #### Local Modules
# `compiler` - [read annotated source code](compiler.html)  
Compiler = require('./compiler')

# ---

# ## CoffeeStand Class
module.exports = class CoffeeStand extends EventEmitter

  # ### Class Properties
  # `@root (String)` : the path to the root directory to watch   
  # `@opts (Objects)` : some options  
  # `@nolint (Bool)` : `true` to avoid linting   
  # `@nojs (Bool)` : `true` to write to a JS file after compilation  
  # `@nolog (Bool)` : `true` to suppress stdout messages  
  # `@lintConfigPath (String)` : a path to a coffeelint configuration file, default to `./coffeelint.json`  
  # `@files (Array)` : path `string`s to currently watching coffee files
  # `@errorFiles (Array)` : path `string`s to compilation error coffee files  
  # `@cmpilers (Object)` : a map object of `Compiler` instances for each file  
  # `@lintConfig (Object)` : coffeelint configrations  
  # `@ignoreFiles (Array)` : glob `String` patterns to ignore files and directories  
  # `@ignoreFile (String)` : a path to the ignore file pattern file  
  # `@mapperFile (String)` : a path to the CS to JS mapping rule  file  
  # `@mapper (Object)` : rules to map `csfile` path to output `jsfile` path
 
  # ### Events
  # `compiled` : compiled a coffee file  
  # `nofile` : the coffee file to compile not found  
  # `write error` : failed to write to a JS file   
  # `compile error` : failed to compile a coffee file  
  # `coffee created` : a coffee file created   
  # `coffee changed` : a coffee file changed     
  # `coffee removed` : a coffee file removed       
  # `watchset` : `fs.watch` is recursively set
 
  # #### constructor
  # `@root` : see *Class Properties* section  
  # `@opts` : see *Class Properties* section
  constructor: (@root = process.cwd(), @opts = {}) ->
    @root = path.resolve(@root)
    @nolint = @opts.nolint ? false
    @nojs = @opts.nojs ? false
    @nolog = @opts.nolog ? true
    @doccoFiles = []
    @lintConfigPath = @opts.lintConfigPath ? path.join(@root, '.coffeelint')
    @_setDoccoSources(@opts.doccoSources)
    @files = []
    @errorFiles = []
    @compilers = {}
    @lintConfig = {nolint: @nolint}
    @ignoreFile = @opts?.ignoreFile ? '.csignore'
    @mapperFile = @opts?.mapperFile ? '.csmapper'
    @ignoreFiles = ['**/.*','**/node_modules']
    if @opts?.ignorePatterns?
      @setIgnoreFiles(@opts.ignorePatterns)
    @mapper = @opts?.mapper ? {}
    @doccoOptions = {
      css: @opts.doccoCSS,
      output: @opts.doccoOutput,
      template: @opts.doccoTemplate
    }
    @_setDocco()
  # ---

  # ### Private Methods

  # #### Set sources for docco
  # `sources (Array)` : a list of sources
  _setDoccoSources: (sources) ->
    if sources?
      @doccoSources = []
      for v in sources
        @doccoSources.push(path.resolve(v))
  # #### check if the given file should be ignored
  # `dir (String)` : a path to a file
  _isIgnore: (file) ->
    for v in @ignoreFiles
      if minimatch(file, v)
        return true
    return false

  # #### Read a .csmapper file and add patterns 
  # `p (String)` : a path to a mapper JSON file, default to `.csmapper`  
  # `cb (Function)` : a callback function  
  _readCSMapper: (p = ".csmapper",cb) ->
    if not p? or typeof(p) is 'function'
      cb = p
      p = ".csignore"
    p = path.resolve(p)
    fs.readFile(p, 'utf8', (err, body) =>
      if not err
        try
          newmapper = JSON.parse(body)
          @mapper = _.extend(@mapper,newmapper)
        catch e
          console.log(e)
      cb(@mapper)
    )

  # #### Read a .csignore file and add patterns 
  # `dir (String)` : a path to a directory  
  # `cb (Function)` : a callback function  
  _readCSIgnore: (p = ".csignore", cb) ->
    if not p? or typeof(p) is 'function'
      cb = p
      p = ".csignore"
    p = path.resolve(p)
    fs.readFile(p, 'utf8', (err, body) =>
      if not err
        patterns = _(body.split('\n')).chain().compact().value()
        @setIgnoreFiles(patterns)
      cb(@ignoreFiles)
    )

  # #### Add a file to @files
  # `file (String)` : a path to a file  
  _addFile: (file) ->
    @files.push(file)

  # #### Remove a file from @files
  # `file (String)` : a path to a file  
  _rmFile: (file) ->
    @files = _(@files).without(file)

  # #### remove a Compiler
  # `file (String)` : a path to the file which the Compiler to remove is on  
  _removeCompiler: (file) ->
    @compilers[file]?.removeAllListeners()
    delete @compilers[file]

  # #### Parse a lint result
  # `lint (Object)` : a result form linting 
  _parseLint: (lint) ->
    errorCount = 0
    warnCount = 0
    if lint.err
      return {message : "\n  lint compile error: #{lint.err}".red, errorCount : errorCount}
    else if lint.length is 0
      return {message : "", errorCount : errorCount}
    else
      errors = []
      for v in lint
        if v.level is 'error'
          errorCount += 1
          lcolor = 'red'
        else if v.level is 'warn'
          lcolor = 'yellow'
          warnCount += 1
        error = [("  ##{v.lineNumber} #{v.message}.")[lcolor]]
        if v.context?
          error.push(" #{v.context}."[lcolor])
        error.push(" (#{v.rule})".grey)
        if v.line
          error.push("\n    => #{v.line}".grey)
        errors.push(error.join(''))
      errors.push(
        "  CoffeeLint: ".grey +
        "#{errorCount} errors".red +
        " #{warnCount} warnings".yellow
      )
      return {message : '\n' + errors.join('\n'), errorCount : errorCount}

  # #### Set a child process for docco operations
  _setDocco: () ->
    @cp_docco = cp.fork(__dirname + '/docco')
    @cp_docco.on('message', (data) =>
      if data.err
        console.log('Docco: something went wrong!\n'.red)
      else
        console.log('Docco: documents successfully generated!\n'.green)
      @emit('docco', data)
    )
    @cp_docco.on('error', (err) =>
      console.log('Docco: something went wrong!\n'.red)
      @_setDocco()
    )

  # #### See if the file should be a source of docco document
  # `filepath (String)` : a path to a file to check
  _isDocco: (filepath) ->
    if @doccoSources?
      for v in @doccoSources
        if minimatch(filepath, v)
          return @doccoSources
          break
      return null
    else
      return null

  # #### take off a file from @doccoFiles`
  _withoutFile: (file) ->
    @doccoFiles = (v for v in @doccoFiles when v isnt file)
    if @doccoFiles.length is 0
      @document()

  # #### Set up a Compiler on a file
  # `filename (String)` : a path to a file to set a Compiler on
  _setCompiler: (filename) ->
    @compilers[filename] = new Compiler(filename, @lintConfig, @mapper)
    @compilers[filename].on('compiled', (data) =>
      unless @nolog
        message = [
          'compiled'.green,
          " - #{data.file}"
        ]
        unless @nojs then message.push(" => #{data.jsfile}".grey)
        unless @nolint then message.push(@_parseLint(data.lint).message)
        console.log(message.join('') + '\n')
      @emit('compiled', data)
      if @doccoFiles.length isnt 0
        @_withoutFile(filename)
      else
        @docco(filename)
    )
    @compilers[filename].on('nofile', (data) =>
      if @doccoFiles.length isnt 0
        @_withoutFile(filename)
      unless @nolog
        console.log('coffee file not found'.yellow + " - #{data.file}\n")
      @emit('nofile',data)
    )
    @compilers[filename].on('write error', (data) =>
      if @doccoFiles.length isnt 0
        @_withoutFile(data.file)
      unless @nolog
        message = [
          'fail to write js file'.yellow,
          " - #{data.file}",
          " -> #{data.jsfile}"
        ]
        console.log(message.join(''), '\n')
      @emit('write error',data)
    )
    @compilers[filename].on('compile error', (data) =>
      if @doccoFiles.length isnt 0
        @_withoutFile(data.file)
      unless @nolog
        console.log(
          'compile error'.red +
          " in #{data.file}" +
          (" => #{data.err}").red+'\n'
        )
      @errorFiles.push(data.file)
      @errorFiles = _(@errorFiles).uniq()
      @emit('compile error', data)
    )
    @compilers[filename].compile(@nojs)

  # ---

  # ### Public API

  # #### Read a configration file for coffeelint
  # `p (String)` : a path to a config file  
  # `cb (Function)` : a callback function  
  getLintConfig: (p = @lintConfigPath, cb) ->
    if typeof(p) is 'function'
      cb = p
      p = @lintConfigPath
    if @nolint is true
      @lintConfig = {nolint: false}
      cb?()
    else
      fs.readFile(p, 'utf8', (err,body) =>
        unless err
          try
            @lintConfig = JSON.parse(body)
            @lintConfig.nolint = false
          catch e
        cb?(@lintConfig)
      )

  # #### Get a list of compilation error coffee files
  getErrorFiles: ->
    return @errorFiles

  # #### Add patterns to @ignoreFile
  # `newFiles (Array)` : glob `String`s to add to `@ignoreFile`  
  setIgnoreFiles: (newFiles) ->
    @ignoreFiles = _(@ignoreFiles).union(newFiles)    

  # #### Unset ignore patterns for the given directory
  # `dir (String)` : a directory path  
  unsetIgnoreFiles: (patterns) ->
    if patterns?
      @ignoreFiles = _(@ignoreFiles).reject((v) ->
        return patterns.indexOf(v) isnt -1
      )
    return @ignoreFiles

  # #### Start Compiler on a file
  # `file (String)` : a file path   
  startCompiler: (file) ->
    @_addFile(file)
    @_setCompiler(file)

  # #### Stop Compiler on a file
  # `file (String)` : a file path   
  stopCompiler: (file) ->
    @_removeCompiler(file)
    @_rmFile(file)

  # #### Kill CoffeeStand by removing all Compilers and Watchers
  kill: (cb) ->
    for v in @files
      @stopCompiler(v)
    cb?()

  # #### Run CoffeeStand
  run: ->
    # First get CoffeeLint config
    @getLintConfig( =>
      # Then get .csignore
      @_readCSIgnore(@ignoreFile, =>
        # Then get .csmapper
        @_readCSMapper(@mapperFile, =>
          # Finally recursively walk through directories
          @watch()
        )
      )
    )

  # #### Recursively watch directories and set a compiler on coffee files
  watch: ->
    fswatchr = new FSWatchr(@root)
    fswatchr.setFilter((dir, path) =>
      for v in @ignoreFiles
        if minimatch(dir, v)
          return true
      return false
    )
    fswatchr.on('File found', (file, stat) =>
      if @_isDocco(file) and path.extname(file) is '.coffee' and not @_isIgnore(file)
        @doccoFiles.push(file)
      @emit('File found', file, stat)
      if path.extname(file) is '.coffee'
        # If a coffee file is found, set a `Compiler` on it
        @startCompiler(file)
    )
    fswatchr.on('watchset', (dirname, filestats) =>
      @emit('watchset', dirname, filestats)
    )
    fswatchr.on('File created', (filename) =>
      if path.extname(filename) is '.coffee' and not @_isIgnore(filename)
        @startCompiler(filename)
        @emit('coffee created', filename)
    )
    fswatchr.on('File changed', (filename,stats) =>
      if path.extname(filename) is '.coffee' and not @_isIgnore(filename)
        @emit('coffee changed', filename)
        @compilers[filename]?.compile?()
    )
    fswatchr.on('File removed', (filename) =>
      if path.extname(filename) is '.coffee' and not @_isIgnore(filename)
        if @compilers[filename]?.jsname? and @compilers[filename]?.rmJS
          rmfn = @compilers[filename]?.rmJS
        else
          rmfn = (cb) =>
            cb()
        rmfn( =>
          @errorFiles = _(@errorFiles).without(filename)
          @stopCompiler(filename)
          @emit('coffee removed', filename)
        )
    )
    fswatchr.watch()

  # #### See if there is a need for docco generation
  # `filename (String)` : a path to the file to check
  docco: (filename) ->
    if @doccoSources? and @doccoFiles.length is 0 and filename? and @_isDocco(filename)
      @document()

  # #### Generate docco documents via a child process
  document: () ->
    # Allow a bit of time before generating docco docs. Auto-saved files such as '.#foo.coffee' will cause an error. These files are likely to be cleared instantly, and docco seems to list up these files, but fails to open them because those files are already gone by the time docco can open them. So don't let docco list up instantly disappearing files by giving it 500ms.
    setTimeout(
      =>
        @cp_docco.send({sources: @doccoSources, options: @doccoOptions})
      500
    )

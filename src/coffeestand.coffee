# * Recursively watch directories and recompile when coffee files are changed
# * Write compiled code to a destination js file, of course  
# * Aware of newly created files and directories too!
#   So you don't have to rewatch every time you add a file
# * [Coffeelint](http://www.coffeelint.org/) the source code after every compilation
# * Ignore Files through glob matching option and .csingore files

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
# `dirwalker` by [Tomo I/O@tomoio](https://github.com/tomoio/dirwalker)  
_ = require('underscore')
minimatch = require('minimatch')
colors = require('colors')
DirWalker = require('dirwalker')

# #### Local Modules
# `watcher` - [read annotated source code](watcher.html)  
# `compiler` - [read annotated source code](compiler.html)  
Watcher = require('./watcher')
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
  # `@dirs (Array)` : path `string`s to currently watching directories  
  # `@files (Array)` : path `string`s to currently watching coffee files
  # `@errorFiles (Array)` : path `string`s to compilation error coffee files  
  # `@watchers (Object)` : a map object of `Watcher` instances for each directory  
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
  # `dir removed` : a directory removed  
  # `dir created` : a directory created   
  # `coffee created` : a coffee file created   
  # `coffee changed` : a coffee file changed     
  # `coffee removed` : a coffee file removed       
  # `walkend` : the initial directory reading operation finished   
  # `watchstart` : `fs.watch` started
 
  # #### constructor
  # `@root` : see *Class Properties* section  
  # `@opts` : see *Class Properties* section
  constructor: (@root = process.cwd(), @opts = {}) ->
    @root = path.resolve(@root)
    @nolint = @opts.nolint ? false
    @nojs = @opts.nojs ? false
    @nolog = @opts.nolog ? true
    @lintConfigPath = @opts.lintConfigPath ? path.join(@root, '.coffeelint')
    @dirs = []
    @files = []
    @errorFiles = []
    @watchers = {}
    @compilers = {}
    @lintConfig = {nolint: @nolint}
    @ignoreFile = @opts?.ignoreFile ? '.csignore'
    @mapperFile = @opts?.mapperFile ? '.csmapper'
    @ignoreFiles = ['**/.*','**/node_modules']
    if @opts?.ignorePatterns?
      @setIgnoreFiles(@opts.ignorePatterns)
    @mapper = @opts?.mapper ? {}

  # ---

  # ### Private Methods

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

  # #### Add a directory to @dirs
  # `dir (String)` : a path to a directory  
  _addDir: (dir) ->
    @dirs.push(dir)

  # #### Add a file to @files
  # `file (String)` : a path to a file  
  _addFile: (file) ->
    @files.push(file)

  # #### Remove a directory from @dirs
  # `dir (String)` : a path to a directory  
  _rmDir: (dir) ->
    @dirs = _(@dirs).without(dir)

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
    )
    @compilers[filename].on('nofile', (data) =>
      unless @nolog
        console.log('coffee file not found'.yellow + " - #{data.file}\n")
      @emit('nofile',data)
    )
    @compilers[filename].on('write error', (data) =>
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

  # #### Close a directoy Watcher
  # `dir (String)` : a path to a directory  
  _closeWatcher: (dir) ->
    @watchers[dir]?.removeAllListeners()
    @watchers[dir]?.close()
    delete @watchers[dir]

  # #### Watch directory for changes and emit events  
  # `dirname (String)` : a path to a directory to watch
  # `cb (Function)` : a callback function
  _watch: (dirname, cb) ->
    @watchers[dirname] = new Watcher(dirname)
    @watchers[dirname].on('dir removed', (filename) =>
      if not @_isIgnore(filename)
        @emit('dir removed', filename)
        @stopWatch(filename)
    )
    @watchers[dirname].on('dir created', (filename) =>
      if not @_isIgnore(filename)
        @startWatch(filename)
        @emit('dir created', filename)
    )
    @watchers[dirname].on('file created', (filename) =>
      if path.extname(filename) is '.coffee' and not @_isIgnore(filename)
        @startCompiler(filename)
        @emit('coffee created', filename)
    )
    @watchers[dirname].on('file changed', (filename,stats) =>
      if path.extname(filename) is '.coffee' and not @_isIgnore(filename)
        @emit('coffee changed', filename)
        @compilers[filename]?.compile?()
    )
    @watchers[dirname].on('file removed', (filename) =>
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
    @watchers[dirname].on('watchstart', =>
      @emit('watchstart', dirname)      
    )
    @watchers[dirname].watch(cb)

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

  # #### Start watching a directory
  # `dir (String)` : a directory path 
  # `cb (Function)` : a callback function 
  startWatch: (dir,cb) ->
    @_addDir(dir)
    @_watch(dir,cb)

  # #### Stop Compiler on a file
  # `file (String)` : a file path   
  stopCompiler: (file) ->
    @_removeCompiler(file)
    @_rmFile(file)

  # #### Stop watching a directory
  # `dir (String)` : a directory path  
  stopWatch: (dir) ->
    @unsetIgnoreFiles(dir)
    @_closeWatcher(dir)
    @_rmDir(dir)

  # #### Kill CoffeeStand by removing all Compilers and Watchers
  kill: (cb) ->
    for v in @dirs
      @stopWatch(v)
    for v in @files
      @stopCompiler(v)
    cb?()

  # #### Recursively Walk through directories and watch them, set up compilers on coffee files
  # `file_cb (Function)` : a callback function to execute when a file is found  
  # `dir_cb (Function)` : a callback function to execute when a directory is found  
  walk: (file_cb, dir_cb) ->
    ignore = @ignoreFiles
    walker = new DirWalker(@root)
    walker.setFilter((dir, path) =>
      for v in @ignoreFiles
        if minimatch(dir, v)
          return true
      return false
    )
    walker.on('File', (file, stat) =>
      file_cb?(file, stat)
    )
    walker.on('Directory', (dir, stat) =>
      dir_cb?(dir, stat)
    )
    walker.on('end', (ret) =>
       @emit('walkend', ret)
    )
    walker.walk()
  # #### Run CoffeeStand
  run: ->
    # First get CoffeeLint config
    @getLintConfig( =>
      # Then get .csignore
      @_readCSIgnore(@ignoreFile, =>
        # Then get .csmapper
        @_readCSMapper(@mapperFile, =>
          # Finally recursively walk through directories
          @walk(
            (file,stat) =>
              if path.extname(file) is '.coffee'
                # If a coffee file is found, set a `Compiler` on it
                @startCompiler(file)
            (dir,stat) =>
              # If a directory is found, watch it for changes
              @startWatch(dir)
          )
        )
      )
    )
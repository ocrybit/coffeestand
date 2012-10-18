# * Recursively walk through directories
# * Emit and execute a given callback every time a file or a directory is found

# ---

# ### Require Dependencies

# #### Standard Node Modules
# `fs` : [File System](http://nodejs.org/api/fs.html)  
# `path` : [Path](http://nodejs.org/api/path.html)  
# `events` : [Events](http://nodejs.org/api/events.html)  
fs = require('fs')
path = require('path')
EventEmitter = require('events').EventEmitter

# #### Third Party Modules
# `underscore` by [DocumentCloud@documentcloud](https://github.com/documentcloud/underscore)  
# `async` by [Caolan McMahon@caolan](https://github.com/caolan/async)  
# `minimatch` by [Isaac Z. Schlueter@issacs](https://github.com/issacs/minimatch)  
_ = require('underscore')
async = require('async')
minimatch = require('minimatch')

# ---

# ## Walker Class
module.exports = class Walker extends EventEmitter

  # ### Class Properties
  # `@root (String)` : the root path to start walking  
  # `@ignoreFiles (Array)` : glob `String`s to match files and directories to ignore  
  # `@dirs (Array)` : stat `Object`s of found directories  
  # `@files (Array)` : stat `Object`s of found files  
  # `@readCount (Number)` : a count to keep track of async readdir processes  
  # `@callbacks (Object)` : callback `Function`s to execute when files and directories are found,
  # only `dir` and `file` are supported

  # ### Events
  # `end` : end `@walk()`  
  # `dir` : found a directory  
  # `file` : found a file  
  # `nofile` : no file exists at the given `@root` path  
  # `not dir` : `@root` is not a directory  

  # #### constructor
  # `@root ()` : see *Class Properties* section  
  # `opts (Object)` : options to pass on to the class  
  # 
  #     {
  #       ignoreFiles: [String Array],
  #       callbacks: {
  #                    dir: [Function],
  #                    file: [Function]
  #                  }
  #     }
  #
  constructor:(@root = process.cwd(), opts = {}) ->
    @ignoreFiles = opts.ignoreFiles ? []
    @callbacks = opts.callbacks
    @dirs = []
    @files = []
    @readCount = 0

  # ---

  # ### Private Methods

  # #### Check if a directory should be ignored
  # `dir (String)` : a directory path to check  
  _isIgnore: (dir) ->
    for v in @ignoreFiles
      if minimatch(dir, v)
        return true
    return false

  # #### End directory walking operation
  # `cb (Function)` : a callback Function
  _end: (cb) ->
    # Emit `end` event
    @emit('end')
    # Execute `@cb` function
    cb?({dirs: @dirs, files: @files})

  # #### When finish reading a directory, check if the whole walking (the other async processes) is done
  # `cb (Function)` : a callback Function 
  _readEnd: (cb) ->
    # -1 for the ended `@readdir()` process
    @readCount -= 1
    # If `@readCount` is `0`, there is no running process left
    if @readCount is 0
      @_end(cb)

  # #### Report a found directory
  # `dir (String)` : a directory path to report  
  # `stat (Object)` : a stat object for `dir`
  # `cb (Function)` : a callback Function  
  _reportDir: (dir, stat, cb) ->
    @dirs.push(dir)
    @emit('dir', dir, stat)
    # +1 for a new `@readdir()` process to be launched below
    @readCount += 1
    # Recursively read directory
    @_readdir(dir, cb)
    @callbacks?.dir?(dir, stat)

  # #### Report a found file
  # `file (String)` : a file found  
  # `stat (Object)` : a stat object for the file 
  _reportFile: (file, stat) ->
    @files.push(file)
    @emit('file', file, stat)
    @callbacks?.file?(file, stat)

  # #### Read a directory and emit events when files or directories are found
  # `dir (String)` : a directory path to read
  # `cb (Function)` : a callback Function
  _readdir: (dir, cb) ->
    fs.readdir(dir, (err, files) =>
      if err
        @dirs = _(@dirs).without(dir)
        @_readEnd(cb)
      else
        # Asyncronously read directories by keeping `@readCount`
        async.forEach(
          files
          (file, callback) =>
            #The full path to `file`
            filepath = path.join(dir, file)
            # Check if `filepath` should be ignored
            if @_isIgnore(filepath)
              callback()
            else
              # Get `file` stats
              fs.stat(filepath, (err, stat) =>
                if err
                  callback()
                else
                  # Check if `file` at `filepath` is a directory
                  if stat.isDirectory()
                    @_reportDir(filepath,stat,cb)
                  # Check if `file` at `filepath` is a file
                  else if stat.isFile()
                    @_reportFile(filepath,stat)
                  callback()
              )
          =>
            # Finish reading `dir`
            @_readEnd(cb)
        )
    )

  # ---

  # ### Public API

  # #### Start resursively walking down directories
  # `cb (Function)` : a callback Function to execute when walking is done  
  walk:(cb) ->
    # If `@root` should be ignored, `@_end()` walking immediately
    if @_isIgnore(@root)
      @_end(cb)
    else
      # Get `@root` file stats
      fs.stat(@root, (err, stat) =>
        # If `@root` doesn't exist, abort by emitting `nofile` event
        if err
          @emit('nofile', err)
          @_end(cb)
        # If `@root` isn't a directory, abort by emitting `not dir` event
        else if not stat.isDirectory()
          @emit('not dir', @root)
          @_end(cb)
        # Otherwise `@_reportDir()` and recursively keep walking
        else
          @_reportDir(@root, stat, cb)
      )
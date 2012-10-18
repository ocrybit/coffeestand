# * Watch a directory and emit events when files are created, changed, and removed

# ---

# ### Require Dependencies

# #### Standard Node Modules
# `events` : [Events](http://nodejs.org/api/events.html)  
# `fs` : [File System](http://nodejs.org/api/fs.html)  
# `path` : [Path](http://nodejs.org/api/path.html)  
EventEmitter = require('events').EventEmitter
fs = require('fs')
path = require('path')

# #### Third Party Modules
# `async` by [Caolan McMahon@caolan](https://github.com/caolan/async)  
async = require('async')

# ---

# ## Watcher Class
module.exports = class Watcher extends EventEmitter

  # ### Class Properties
  # `@dir (String)` : a directory path to watch  
  # `@dirs (Object)` : stats of files and directories under the watch  
  # `@watcher (Object)` : [`fs.FSWatcher`](http://nodejs.org/api/fs.html#fs_class_fs_fswatcher) object
 
  # ### Events
  # `file created` : a file is created  
  # `file changed` : a file is changed  
  # `file removed` : a file is removed  
  # `dir created` : a directory is created  
  # `dir changed` : a directory is changed  
  # `dir removed` : a directory is removed  
  # `watchstart` : `fs.watch started    
    
  # #### constructor
  # `@dir` : see *Class Properties* section  
  constructor: (@dir = process.cwd()) ->
    @dirs = {}

  # ---

  # ### Private Methods

  # #### Check if the mtime of the previous stats and the new stats are the same
  # `filename (String)` : filename  
  # `stats (object)` : the new stats of the file 
  _checkMtime: (filename, newstats) ->
    # get the previously stored stats for the `filename`
    oldstats = @dirs[filename]
    if oldstats?.mtime?.getTime() is newstats?.mtime?.getTime()
      return true
    else
      return false

  # #### Get the type of the file
  # `stats (object)` :  a stats object
  _getType: (stats) ->
    if stats?.isDirectory()
      return 'dir'
    else if stats?.isFile()
      return 'file'
    else
      return false

  # #### Specify the action taken on the file
  # `event (String)` : an event name  
  # `filename (String)` : a file name  
  # `stats (Object)` : a stats object
  _getAction: (event, filename, stats) ->
    switch event
      when 'rename'
        # If the stats object is not stored in `@dirs`, the file is newly `created`
        return if (@dirs[filename]? and not stats?) then 'removed' else 'created'
      when 'change'
        # If the `mtime` hasn"t changed, the file content is `unchanged`
        return if @_checkMtime(filename,stats) then 'unchanged' else 'changed'
  
  # #### Before the watch, read the directory and stored file stats for later comparison
  # `cb (Function)` : a callback function
  _readdir: (cb) ->
    fs.readdir(@dir, (err, directories) =>
      @dirs = {}
      # asyncronously get the file stats
      async.forEach(
        directories,
        (v, callback) =>
          fs.stat(path.join(@dir,v), (err, stats) =>
            if not err
              @dirs[v] = stats
            callback()
          )
        =>
          cb?(@dirs)
      )
    )

  # ---

  # ### Public API
 
  # #### Watch directory and emit events when changes are found
  # `cb (Function)` : a callback function
  watch: (cb) ->
    @_readdir(() =>
      @watcher = fs.watch(@dir, (event, filename) =>
        fs.stat(path.join(@dir, filename), (err, stats) =>
          action = @_getAction(event, filename, stats)
          type = @_getType(stats ? @dirs[filename])
          if action is 'removed' and @dirs[filename]?
            # Remove the stored stats
            delete @dirs[filename]
          else if stats?
            # Replace the stored stats with new stats
            @dirs[filename] = stats
          unless type is false or action is 'unchanged'
            # emit `created`, `changed` and `removed` events for files and directories
            @emit("#{type} #{action}", path.join(@dir, filename), stats)
        )
      )
      cb?(@dirs)
      @emit("watchstart", @dir)
    )

  # #### Close fs.FSWatcher and remove stored stats
  close: ->
    @watcher?.close()
    @dirs = []

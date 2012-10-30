CoffeeStand
===========

A recursive CoffeeScript watcher also aware of newly added files. [The built-in CoffeeScript watcher](http://coffeescript.org/#usage) doesn't work this way. Now you can start **CoffeeStand** at your root directory once and for all and forget about restarting the watch process every time you add a new file.

The simplest way to recursively watch your entire project from the command-line is run `coffeestand` in the project root directory.

    coffeestand

Features
--------
* Recursively watch directories and auto-recompile when coffee files are changed.
* Write compiled code to destination js files.
* Aware of newly created files and directories too! So you don't have to rewatch every time you add a file.
* Also Aware of newly created directories and files inside.
* Auto-[Coffeelint](http://www.coffeelint.org/) (not JSLint) the source code after every compilation.
* Ignore Files through glob matching option and `.csingore` file
* Outupt JS dir & file mapping through `.csmapper` file
* Auto-generate [docco](http://jashkenas.github.com/docco/) documents after every compilation

Installation
------------

Use [npm](https://npmjs.org/), `-g` option is recommended so you can globally use `coffeestand` CLI.

    sudo npm install -g coffeestand

Command Line Usage
------------------

    coffeestand <dir> [options]

`dir` : the root directory to watch, CoffeeStand walks down its sub directories and watches the entire project tree. If omitted, `dir` will be set `./` which is the current working directory.

#### options

`--nolog` : supress the stdout log messages, useful when using the coffeestand module in your node scripts  
`--nojs` : don't write compiled code to JS files, useful if you just want to see how compilation goes  
`--nolint` : don't coffeelint after compilation  
`-l` `--lintconfig` : path to the [coffeelint configuration](http://www.coffeelint.org/#options) file, default to `.coffeelint`  
`-m` `--mapper` : path to the CS to JS mapping file, default to `.csmapper`  
`-i` `--ignore` : path to the ignore setting file, default to `.csignore`  
`-p` `--ipatterns` : comma separeted glob patterns to ignore files, you can also use `.csignore` file to do the same  
`-d` `--docco` : comma separeted paths of docco sources  
`--doccooutput` : a path to the docco output location  
`--doccocss` : a path to the docco css file  
`--doccotemplate` : a path to the docco template file

CoffeeLint
----------

CoffeeStand does auto-[CooffeeLint](http://www.coffeelint.org/) your coffeescript files after every compilation to keep your code clean. You can suppess this feature by passing `--nolint` option.

To change the default configurations, put `.coffeelint` file in your project root directory. You can also put config file at a defferent location, just pass `-l` or `--lintconfig` option followed by your arbitrary location to the config file.

See [CoffeeLint website](http://www.coffeelint.org/#options) for the lint options and an example configuration file.

Docco
-----

CoffeeStand also auto-generates [docco](http://jashkenas.github.com/docco/) documents after every compilation. This feature is optional and you can enable it by passing `--docco` (`-d` for short) option with a comma separated source list.

For this CoffeeStand project, I process coffee files in the `src` directory and put the resulting html files into docco's default output directory `docs`.

    coffeestand -d "./src/*"

If you are in the root directory of the project, this should just do it. Note you may want to put `"` around the comma separated source list when you use a single pattern like this example, because CoffeeStand uses [commander.js](http://visionmedia.github.com/commander.js/) to process command line options, and it seems to auto-resolve the `*` parts of the source list, which means if you pass  

    coffeestand -d ./src/*

`./src/*` will turn into something like `./src/coffeestand.coffee`, the first actual file that matches the `./src/*` pattern, and it's not going to cover the rest of the files inside `src`.

For docco options, CoffeeStand uses `--doccooutput`, `--doccocss`, `--doccotemplate` respectively. See [the git hub docco page](https://github.com/jashkenas/docco) for details on the docco options.

Ignore File Settings
--------------------

You can make CoffeeStand to ignore some files and directories eather by

1. passing `--ipatterns` (`-p` for short) option followed by comma separated glob patterns  
or  
2. putting `.csignore` file in your project root directory

If you use a location other than `/path/to/project/root/.csignore`, just pass `-i` (`--ignore` for short) option with your arbitrary location.

CoffeeStand uses glob patterns to match file paths using [minimatch](https://github.com/isaacs/minimatch) module.

#### examples

    **/node_modules
    **/.*

The above patterns ignore *node_modules* directory and *dot files*, convenient for git users and node module developers.  

If the parent directory is ignored CoffeeStand doesn't go into its sub directories so it can efficiently reduce the number of watch processes.  

These 2 patterns are indeed set as default values to ease node module development.  

Add your patterns by setting a `.csignore` (can be a different name) file and write one glob pattern per line. Ignore Patterns can be also specified as an inline command line option. Separate the patterns with a comma and give it to coffeestand command with `-p` or `--ipatterns` option.

    coffeestand -p **/node_modules,**/.*

Output JS File Mapping
----------------------

By default, CoffeeStand saves compiled JS code to a JS file in the same directory the original coffeescript file is in, that is, /path/to/project/foo.coffe will be compiled to /path/to/project/foo.js. To change this behavior, you can put `.csmapper` JSON file into the project root directory.

#### examples

An example `.csmapper` file would look something like this

    {"**/src/*" : [/\/src\//, "/lib/"]}
	
This is what I use to auto-compile the coffee files in the `src` directories into the `lib` directory. I use CoffeeStand to watch files while developing CoffeeStand. So this applies to the source tree of this node module repo and it works.

1. The content of `.csmapper` must be JSON formatted that can be parsed by `JSON.parse()`
2. Each mapping pattern is a key-value pair
3. The key is a glob and put in a pattern matching test against file paths
4. If the glob key matches a file path, the path is replaced using the Javascript `replace()` method with the value array as arguments to `replace()`

So in the above example, `**/src/*` matches `/project/root/src/foo.coffee`, and `[/\/src\//, "/lib/"]` turns to `replace(/\/src\//, "/lib/")` and replaces the path to `/project/root/lib/foo.js`.  

The `.coffee` extension will be auto-replaced to `.js`.  

You can put as many key-value pairs as you want in a `.csmapper` file  

Putting multiple patterns in `.csmapper`

    {
	  "**/src/*" : [/\/src\//, "/lib/"],
	  "**/cofffe/*" : ["before", "after"],	  
	  ........,
	  ........
	}
	
`.csmapper` can be named differently and put at a different location, in such cases, pass `-m` or `--mapper` followed by the file location as a command line option.

    coffeestand -m /path/to/your/mapping/file.json

In Your Node Scripts
--------------------

CoffeeStand can be also used in your node scripts as a module.  

    CoffeeStand = require('coffeestand')


see [annotated sorce code](http://tomoio.github.com/coffeestand/docs/coffeestand.html) for more details  

Running Tests
-------------

Run tests with [mocha](http://visionmedia.github.com/mocha/)

    make
	
License
-------
**CoffeeStand** is released under the **MIT License**. - see [LICENSE](https://raw.github.com/tomoio/coffeestand/master/LICENSE) file

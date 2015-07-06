#
# フロントエンド開発用 汎用gruntテンプレート
# v3.0.0
#

# ---------------------------------------------------------
#  設定
# ---------------------------------------------------------

# ソースディレクトリ
SRC_DIR = './src'

# 納品ディレクトリ
PUBLISH_DIR = '../htdocs'

# タスクから除外するためのプレフィックス
EXCRUSION_PREFIX = '_'

# ライブラリを格納するディレクトリ名
LIBRARY_DIR_NAME = 'lib'

# autoprefixerのオプション
AUTOPREFIXER_OPT = ['last 2 versions', 'ie 8', 'ie 9']

# jadeで読み込むjson
DATA_JSON = "#{SRC_DIR}/#{EXCRUSION_PREFIX}data.json"

# assetsディレクトリへドキュメントルートからの相対パス
ASSETS_DIR = 'assets'

# clean対象のディレクトリ (除外したいパスがある場合にnode-globのシンタックスで指定)
CLEAN_DIR = [ PUBLISH_DIR ]

# 各種パス
paths =
  html    : "**/*.html"
  jade    : "**/*.jade"
  assemble: "**/*.hbs"
  css     : "**/*.css"
  sass    : "**/*.{sass,scss}"
  js      : "**/*.js"
  json    : "**/*.json"
  coffee  : "**/*.coffee"
  cson    : "**/*.cson"
  img     : [ "**/img/**" ]
  others  : [
    "**/*"
    "**/.htaccess"
    "!**/*.{html,jade,hbs,css,sass,scss,js,json,coffee,cson,md}"
    "!**/img/**"
  ]
  jadeInclude: [
    "**/#{EXCRUSION_PREFIX}*/**/*.jade"
    "**/#{EXCRUSION_PREFIX}*.jade"
  ]
  assembleInclude: [
    "**/#{EXCRUSION_PREFIX}*/**/*.hbs"
    "**/#{EXCRUSION_PREFIX}*.hbs"
  ]
  sassInclude: [
    "**/#{EXCRUSION_PREFIX}*/**/*.{sass,scss}"
    "**/#{EXCRUSION_PREFIX}*.{sass,scss}"
  ]
  coffeeInclude: [
    "**/#{EXCRUSION_PREFIX}*/**/*.coffee"
    "**/#{EXCRUSION_PREFIX}*.coffee"
  ]



# ---------------------------------------------------------
#  内部関数
# ---------------------------------------------------------

# タスク対象のファイル、ディレクトリの配列を生成
_createSrcArr = (name)->
  [].concat paths[name], [
    "!**/#{EXCRUSION_PREFIX}*"
    "!**/#{EXCRUSION_PREFIX}*/"
    "!**/#{EXCRUSION_PREFIX}*/**"
  ]

# gulpのログの形式でconsole.log
_msg = (msg)->
  d = new Date()
  console.log "[#{util.colors.gray(d.getHours() + ':' + d.getMinutes() + ':' + d.getSeconds())}] #{msg}"


# ---------------------------------------------------------
#  grunt設定
# ---------------------------------------------------------


module.exports = (grunt) ->
  # 設定用のオブジェクト
  conf =
    watch: {}
    uglify: {}
    coffee: {}

  # -------------------------------
  #  タスク定義
  # -------------------------------

  tasks =
    html: [
      'jade'
      'assemble'
      'copy:html'
    ]
    css: [
      'sass'
      'copy:css'
      'autoprefixer'
    ]
    js: [
      'coffee'
      'copy:js'
    ]
    json: [
      'jsonlint'
      'copy:json'
    ]
    img: [
      'copy:img'
    ]
    watcher: [
      'notify:watch'
      'connect'
      'watch'
    ]
    default: [
      'clean'
      'js'
      'json'
      'img'
      'css'
      'html'
      'copy:others'
      'notify:build'
    ]


  # -------------------------------
  #  個別タスク生成用関数
  # -------------------------------

  #
  # spritesmith のタスクを生成
  #
  # @param {String}  taskName      タスクを識別するための名前 すべてのタスク名と異なるものにする
  # @param {String}  imgDir        ソース画像ディレクトリへのパス (ドキュメントルートからの相対パス)
  # @param {String}  cssDir        ソースCSSディレクトリへのパス (ドキュメントルートからの相対パス)
  # @param {String}  outputImgName 指定しなければ#{taskName}.pngになる (拡張子なし)
  # @param {String}  outputImgPath CSSに記述される画像パス (相対パスの際に指定する)
  # @param {Boolean} compressImg   画像を圧縮するかどうか
  #
  # #{SRC_DIR}#{imgDir}/_#{taskName}/
  # 以下にソース画像を格納しておくと
  # #{SRC_DIR}#{cssDir}/_#{taskName}.scss と
  # #{SRC_DIR}#{imgDir}/#{taskName}.png が生成される
  # かつ watch タスクの監視も追加
  #
  createSpritesTask = (taskName, imgDir, cssDir, outputImgName = '', outputImgPath = '', compressImg = false) ->
    imgPath = "#{SRC_DIR}/#{imgDir}/#{outputImgName or taskName}.png"

    if !conf.hasOwnProperty('sprite')
      tasks.img.unshift 'sprite'
      conf.sprite = {}

    if compressImg
      if !conf.hasOwnProperty('imagemin')
        conf.imagemin = {}
        tasks.img.unshift 'imagemin'
      conf.imagemin[taskName] =
        src: imgPath
        dest: imgPath
        options: optimizationLevel: 3

    srcImgFiles = "#{imgDir}/#{EXCRUSION_PREFIX}#{taskName}/*"
    paths.img.push "!#{srcImgFiles}"

    conf.sprite[taskName] =
      src: "#{SRC_DIR}/#{srcImgFiles}"
      dest: imgPath
      destCss: "#{SRC_DIR}/#{cssDir}/#{EXCRUSION_PREFIX}#{taskName}.scss"
      algorithm: 'binary-tree'
      padding: 2
      cssOpts:
        variableNameTransforms: ['camelize']

    if outputImgPath then conf.sprite[taskName].imgPath = outputImgPath

    conf.watch[taskName] =
      files: srcImgFiles
      tasks: [ "sprite:#{taskName}" ]


  #
  # coffee scriptでconcatする場合のタスクを生成
  #
  # @param {String}       taskName        タスクを識別するための名前 すべてのタスク名と異なるものにする
  # @param {Array|String} src             ソースパス node-globのシンタックスで指定 (ドキュメントルートからの相対パス)
  # @param {String}       outputDir       最終的に出力されるjsが格納されるディレクトリ (ドキュメントルートからの相対パス)
  # @param {String}       outputFileName  最終的に出力されるjsファイル名(拡張子なし)
  #
  createCoffeeExtractTask = (taskName, src, outputDir, outputFileName) ->
    if src instanceof String then src = [ src ]

    for srcPath in src then paths.coffeeInclude.push "!#{srcPath}"

    conf.coffee[taskName] =
      src: for srcPath in src then "#{SRC_DIR}/#{srcPath}"
      dest: "#{PUBLISH_DIR}/#{outputDir}/#{outputFileName}.js"
      options: join: true

    conf.watch[taskName] =
      files: src
      tasks: [ "coffee:#{taskName}" ]

    if grunt.option('release') then conf.watch[taskName].tasks.push "newer:uglify:default"


  #
  # browserifyのタスクを生成
  #
  # @param {String}       taskName        タスクを識別するための名前 すべてのタスク名と異なるものにする
  # @param {Array|String} entries         browserifyのentriesオプションに渡す node-globのシンタックスで指定 (ドキュメントルートからの相対パス)
  # @param {Array|String} src             全ソースファイル (watchタスクで監視するため) node-globのシンタックスで指定 (ドキュメントルートからの相対パス)
  # @param {String}       outputDir       最終的に出力されるjsが格納されるディレクトリ (ドキュメントルートからの相対パス)
  # @param {String}       outputFileName  最終的に出力されるjsファイル名(拡張子なし)
  #
  createBrowserifyTask = (taskName, entries, src, outputDir, outputFileName) ->
    if !conf.hasOwnProperty('browserify')
      tasks.js.unshift 'browserify'
      conf.browserify = {}

    if entries instanceof String then entries = [ entries ]
    for entryPath in entries then paths.coffeeInclude.push "!#{entryPath}"

    if src instanceof String then src = [ src ]
    for srcPath in src then paths.coffeeInclude.push "!#{srcPath}"

    conf.browserify[taskName] =
      src: for entry in entries then "#{SRC_DIR}/#{entry}"
      dest: "#{PUBLISH_DIR}/#{outputDir}/#{outputFileName}.js"
      options:
        transform: [ 'coffeeify', 'debowerify' ]
        browserifyOptions:
          extensions: [ '.coffee' ]

    conf.watch[taskName] =
      files: [].concat entries, src
      tasks: [ "browserify:#{taskName}" ]

    if grunt.option('release') then conf.watch[taskName].tasks.push "newer:uglify:default"


  #
  # javascriptのconcatタスクを生成
  #
  # @param {String}       taskName        タスクを識別するための名前 すべてのタスク名と異なるものにする
  # @param {Array|String} src             ソースパス node-globのシンタックスで指定
  # @param {String}       outputDir       最終的に出力されるjsが格納されるディレクトリ
  # @param {String}       outputFileName  最終的に出力されるjsファイル名(拡張子なし)
  #
  createJsConcatTask = (taskName, src, outputDir, outputFileName = 'lib')->
    if !conf.hasOwnProperty('concat')
      tasks.js.unshift 'concat'
      conf.concat = {}

    outputFilePath = "#{PUBLISH_DIR}/#{outputDir}/#{outputFileName}.js"
    conf.concat[taskName] =
      src: for srcPath in src then "#{SRC_DIR}/#{srcPath}"
      dest: outputFilePath
      options:
        separator: ';'

    conf.uglify[taskName] =
      src: outputFilePath
      filter: 'isFile'
      dest: outputFilePath
      options:
        preserveComments: 'some'

    conf.watch[taskName] =
      files: src
      tasks: [
        "concat:#{taskName}"
        "uglify:#{taskName}"
      ]

    tasks.js.push "uglify:#{taskName}"


  # -------------------------------
  # 個別タスク設定
  # -------------------------------

  # # lib.js
  # createJsConcatTask(
  #   'concatLibJs'
  #   [ "#{ASSETS_DIR}/js/_lib/**/*" ]
  #   "#{ASSETS_DIR}/js"
  #   'lib'
  # )

  # # concatCoffeeTest.js
  # createCoffeeExtractTask(
  #   'concatCoffeeTest'
  #   [
  #     "#{ASSETS_DIR}/js/_concatCoffeeTest/game.coffee"
  #     "#{ASSETS_DIR}/js/_concatCoffeeTest/Root.coffee"
  #     "#{ASSETS_DIR}/js/_concatCoffeeTest/Sound.coffee"
  #     "#{ASSETS_DIR}/js/_concatCoffeeTest/_debugger.coffee"
  #   ]
  #   "#{ASSETS_DIR}/js"
  #   'concatCoffeeTest'
  # )

  # # browerifyTest.js
  # createBrowserifyTask(
  #   'browerifyTest'
  #   [ "#{ASSETS_DIR}/js/_browserifyTest/main.coffee" ]
  #   [ "#{ASSETS_DIR}/js/_browserifyTest/**/*" ]
  #   "#{ASSETS_DIR}/js"
  #   'browerifyTest'
  # )

  # # indexSprites
  # createSpritesTask 'indexSprites', "#{ASSETS_DIR}/img", "#{ASSETS_DIR}/css", 'sprites', '../img/sprites.png', true


  ### 個別タスク設定ここまで ###


  # -------------------------------
  # タスク設定
  # -------------------------------
  conf = require('node.extend') true, conf,

    #############
    ### clean ###
    #############

    clean:
      src: CLEAN_DIR
      options:
        force: true


    ############
    ### copy ###
    ############

    copy:
      html:
        expand: true
        cwd: SRC_DIR
        src: _createSrcArr 'html'
        filter: 'isFile'
        dest: PUBLISH_DIR

      css:
        expand: true
        cwd: SRC_DIR
        src: _createSrcArr 'css'
        filter: 'isFile'
        dest: PUBLISH_DIR

      js:
        expand: true
        cwd: SRC_DIR
        src: _createSrcArr 'js'
        filter: 'isFile'
        dest: PUBLISH_DIR

      json:
        expand: true
        cwd: SRC_DIR
        src: _createSrcArr 'json'
        filter: 'isFile'
        dest: PUBLISH_DIR

      img:
        expand: true
        cwd: SRC_DIR
        src: _createSrcArr 'img'
        filter: 'isFile'
        dest: PUBLISH_DIR

      others:
        expand: true
        cwd: SRC_DIR
        src: _createSrcArr 'others'
        filter: 'isFile'
        dest: PUBLISH_DIR


    ############
    ### html ###
    ############

    jade:
      options:
        pretty: true
        basedir: SRC_DIR
        data: ->
          return grunt.file.readJSON DATA_JSON
      default:
        expand: true
        cwd: SRC_DIR
        src: _createSrcArr 'jade'
        filter: 'isFile'
        dest: PUBLISH_DIR
        ext: '.html'

    assemble:
      options:
        layoutdir: "#{SRC_DIR}/#{ASSETS_DIR}/_assembleLayout"
        partials: "#{SRC_DIR}/#{ASSETS_DIR}/_assembleInclude/**/*.hbs"
        data: DATA_JSON
      default:
        expand: true
        cwd: SRC_DIR
        src: _createSrcArr 'assemble'
        filter: 'isFile'
        dest: PUBLISH_DIR
        ext: '.html'


    ###########
    ### css ###
    ###########

    sass:
      options:
        unixNewlines: true
        sourcemap: 'none'
        style: 'expanded'
      default:
        expand: true
        cwd: SRC_DIR
        src: _createSrcArr 'css'
        filter: 'isFile'
        dest: PUBLISH_DIR
        ext: '.css'

    autoprefixer:
      options:
        browsers: [ 'last 2 versions', 'ie 8', 'ie 9', 'Android 4', 'iOS 8' ]
      default:
        expand: true
        cwd: PUBLISH_DIR
        src: '**/!(_)*.css'
        filter: 'isFile'
        dest: PUBLISH_DIR
        ext: '.css'


    ##############
    ### js ###
    ##############

    coffeelint:
      default:
        expand: true
        cwd: SRC_DIR
        src: paths.coffee
        filter: 'isFile'
        options:
          camel_case_classes: level: 'ignore'
          max_line_length: level: 'ignore'
          no_unnecessary_fat_arrows: level: 'ignore'

    coffee:
      default:
        expand: true
        cwd: SRC_DIR
        src: _createSrcArr 'coffee'
        filter: 'isFile'
        dest: PUBLISH_DIR
        ext: '.js'
        options:
          bare: false
          sourceMap: false


    ############
    ### json ###
    ############

    jsonlint:
      default:
        expand: true
        cwd: SRC_DIR
        src: paths.json
        filter: 'isFile'


    ##############
    ### uglify ###
    ##############

    uglify:
      default:
        expand: true
        cwd: PUBLISH_DIR
        src: paths.js
        filter: 'isFile'
        dest: PUBLISH_DIR
        options: preserveComments: 'some'


    #############
    ### watch ###
    #############

    watch:
      options:
        cwd: SRC_DIR
        livereload: true
        spawn: false

      html:
        files: _createSrcArr 'html'
        tasks: [ 'newer:copy:html' ]

      jade:
        files: _createSrcArr 'jade'
        tasks: [ 'newer:jade' ]

      assemble:
        files: _createSrcArr 'assemble'
        tasks: [ 'newer:assemble' ]

      css:
        files: _createSrcArr 'css'
        tasks: [
          'newer:copy:css'
          'autoprefixer'
        ]

      sass:
        files: _createSrcArr 'sass'
        tasks: [ 'newer:sass' ]

      js:
        files: _createSrcArr 'js'
        tasks: [
          'newer:copy:js'
        ]

      json:
        files: _createSrcArr 'json'
        tasks: [
          'newer:jsonlint'
          'newer:copy:json'
        ]

      coffee:
        files: _createSrcArr 'coffee'
        tasks: [ 'newer:coffee:default' ]

      img:
        files: _createSrcArr 'img'
        tasks: [ 'newer:copy:img' ]

      others:
        files: _createSrcArr 'others'
        tasks: [ 'newer:copy:others' ]

      jadeAll:
        files: paths.jadeInclude
        tasks: [ 'jade' ]

      assembleAll:
        files: paths.assembleInclude
        tasks: [ 'assemble' ]

      sassAll:
        files: paths.sassInclude
        tasks: [ 'sass' ]

      coffeeAll:
        files: paths.coffeeInclude
        tasks: [
          # 'newer:coffeelint'
          'coffee:default'
        ]


    ###############
    ### connect ###
    ###############

    #
    # ローカルサーバー (Connect) と LiveReload タスク
    #
    # * [grunt-contrib-connect](https://github.com/gruntjs/grunt-contrib-connect)
    # * [grunt-contrib-livereload](https://github.com/gruntjs/grunt-contrib-livereload)
    #
    connect:
      publish:
        options:
          livereload: true
          hostname: '0.0.0.0'
          port: 50000
          base: PUBLISH_DIR
          open: 'http://localhost:<%= connect.publish.options.port %>/'
          middleware: (conn, opt)->
            connectSSI = require 'connect-ssi'
            return [
              connectSSI
                baseDir: PUBLISH_DIR
                ext: '.html'
              conn["static"](opt.base[0])
            ]


    ##############
    ### notify ###
    ##############

    notify:
      build:
        options:
          title: 'grunt'
          message: 'build complete!!'
      watch:
        options:
          title: 'grunt watcher'
          message: 'start local server. http://localhost:50000/'


    #############
    ### bower ###
    #############

    bower:
      default:
        options:
          targetDir: "#{SRC_DIR}/#{ASSETS_DIR}"
          layout: (type, component, source)->
            if source.match /(.*)\.css/ then return "css/#{EXCRUSION_PREFIX}#{LIBRARY_DIR_NAME}"
            if source.match /(.*)\.js/ then return "js/#{EXCRUSION_PREFIX}#{LIBRARY_DIR_NAME}"
          install: true
          verbose: true
          cleanTargetDir: false
          cleanBowerDir: true


  # -------------------------------
  # uglify設定
  # -------------------------------
  if grunt.option('release')
    tasks.js.push 'uglify:default'
    conf.watch.js.tasks.push 'newer:uglify:default'
    conf.watch.coffee.tasks.push 'newer:uglify:default'
    conf.watch.coffeeAll.tasks.push 'newer:uglify:default'


  # -------------------------------
  # grunt イニシャライズ
  # -------------------------------

  # 個別タスク設定
  require('load-grunt-tasks') grunt

  # 初期設定オブジェクトの登録
  grunt.initConfig conf

  # 実行タスクの登録
  grunt.registerTask 'init',    tasks.init
  grunt.registerTask 'css',     tasks.css
  grunt.registerTask 'html',    tasks.html
  grunt.registerTask 'img',     tasks.img
  grunt.registerTask 'js',      tasks.js
  grunt.registerTask 'json',    tasks.json
  grunt.registerTask 'watcher', tasks.watcher
  grunt.registerTask 'default', tasks.default

path = require('path')
fs = require('fs')
uglifyJs = require('uglify-js')

# DocPad Configuration File
# http://docpad.org/docs/config

# Define the DocPad Configuration
docpadConfig = {
  poweredByDocPad: false
  templateData:
    site:
      url: "http://yoursite.com"
      mail: "webmaster@yoursite.com"
    getRelativeUrl: (doc) ->
      # Cut hash part and split relative paths including filename by slash (/)
      splitPath = (path) ->
        hash = ''
        hashPos = path.indexOf '#'
        if hashPos > 0
          hash = path.substr hashPos
          path = path.substr 0, hashPos

        parts = path.split '/'
        [parts, hash]

      from = @document.relativeOutPath
      if typeof doc is 'string'
        to = doc
      else
        to = doc.relativeOutPath

      [fromParts] = splitPath from
      [toParts, toHash] = splitPath to

      # Remove common parent directories
      while fromParts.length > 1 && toParts.length > 1 && fromParts[0] == toParts[0]
        fromParts.shift()
        toParts.shift()

      # build relative path
      i = fromParts.length - 1
      while i-- > 0
        toParts.unshift '..'

      result = toParts.join('/') + toHash

      #console.log('from', from, 'to', to, 'result', result)

      result
    obfuscate: (s) ->
      hex = ''
      i = 0
      while (i < s.length)
        hex += s.charCodeAt(i++).toString(16)

      js =  '(function(d,s,f,p,r){'
      js +=   'd.write('
      js +=     's.replace(/../g,function(c){'
      js +=       'return f(p(c,r));'
      js +=     '})'
      js +=   ');'
      js += '})(document,\'' + hex + '\',String.fromCharCode,parseInt,1<<4);'
      '<script type="text/javascript">' + js + '</script><noscript>Please enable javascript</noscript>'

  collections:
    pages: ->
      @getCollection("html").findAllLive({fullDirPath: /documents/}).on "add", (model) ->
        # Set default meta data
        model.setDefaults({layout: 'default', lang: 'DE-de', description: "Docpad Bootstrap"})
        model.setMeta('navTitle', model.get('title')) if !model.get('navTitle')
        #console.log(JSON.stringify(model, 0, 2))

  events:
    writeBefore: (opts) ->
      # Exclude less files
      {collection} = opts
      docpad = @docpad

      collection.findAll({outExtension: 'less'}).forEach (model) ->
        model.set('write', false)

      # Exclude js files but app.js
      collection.findAll({extension: 'js'}).forEach (model) ->
        model.set('write', false) if model.get('basename') != 'app'

      # Include required javascript files
      collection.findAll({basename: 'app', extension: 'js'}).forEach (model) ->

        # Include require files recursivly
        includeRequired = (file, content) ->
          # Read content if not given
          fileDirPath = file.replace(/\/[^\/]+$/, '')
          content = fs.readFileSync(file).toString() if !content
          # Split lines, search for //= require pattern and include file
          lines = content.split(/\n/).map (line) ->
            line.replace /^\/\/= require (.+)(\/\/|\/*|$)/, (l, filename) ->
              filename = filename.replace(/(^[ '"]+|[ '"]+$)/g, '')
              file = path.normalize fileDirPath + '/' + filename
              includeRequired file
          lines.join('\n')

        file = model.get('fullDirPath') + '/' + model.get('filename')
        content = includeRequired file, model.get('contentRendered')
        model.set('contentRendered', content)

      # Minify js file
      collection.findAll({basename: 'app', extension: 'js'}).forEach (model) ->
        # Extract copyright comments and put them to the head
        minifyJs = (content) ->
          comments = []
          content.replace /((\/\*\*?\!([^*]|[*][^\/])+\*\/)|(\/\/\![^\n]+\n))/g, (m, c) ->
            comments.push c
          out = comments.join('')
          out += uglifyJs.minify(content, {fromString: true}).code
          out

        env = docpad.config.env || 'development'
        model.set('contentRendered', minifyJs model.get('contentRendered')) unless env.match(/^dev/)

  plugins:
    copy:
      openSans:
        src: 'bower_components/open-sans-fontface/fonts/Regular'
        out: 'fonts'
      fontawesome:
        src: 'bower_components/fontawesome/fonts'
        out: 'fonts'
    sitemap:
      cachetime: 600000
      changefreq: 'monthly'
      priority: 0.5
      filePath: 'sitemap.xml'
}

# Export the DocPad Configuration
module.exports = docpadConfig

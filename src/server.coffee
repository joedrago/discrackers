# ---------------------------------------------------------------------------------------
# Modules

cookieParser = require 'cookie-parser'
Database = require './Database'
express = require 'express'
fs = require 'fs'
https = require 'https'

# ---------------------------------------------------------------------------------------
# Globals

secrets = null
database = null

# ---------------------------------------------------------------------------------------
# Helpers

fatalError = (reason) ->
  console.error "FATAL: #{reason}"
  process.exit(1)

findFlatIssues = (manifest, dirPrefix) ->
  issues = []
  for issue in manifest.flat
    if issue.dir.indexOf(dirPrefix) == 0
      issues.push issue
  return issues

# ---------------------------------------------------------------------------------------
# Authentication

processOAuth = (code) ->
  console.log "processOAuth: #{code}"
  return new Promise (resolve, reject) ->
    if not code? or (code.length < 1)
      resolve('')
      return

    postdata =
      client_id: secrets.discordClientID
      client_secret: secrets.discordClientSecret
      grant_type: 'authorization_code'
      redirect_uri: secrets.url + '/oauth'
      code: code
      scope: 'identify'
    params = String(new URLSearchParams(postdata))

    options =
      hostname: 'discord.com'
      port: 443
      path: '/api/oauth2/token'
      method: 'POST'
      headers:
        'Content-Length': params.length
        'Content-Type': 'application/x-www-form-urlencoded'
    req = https.request options, (res) ->
      rawJSON = ""
      res.on 'data', (chunk) ->
        rawJSON += chunk
      res.on 'error', ->
        console.log "Error getting auth"
        resolve('')
      res.on 'end', ->
        data = null
        try
          data = JSON.parse(rawJSON)
        catch
          console.log "ERROR: Failed to talk to parse JSON: #{rawJSON}"
          resolve('')
          return

        # console.log "Discord replied: ", JSON.stringify(data, null, 2)
        if not data.access_token? or (data.access_token.length < 1) or not data.token_type? or (data.token_type.length < 1)
          console.log "bad oauth reply (no access_token or token_type):", data
          resolve('')
          return

        meOptions =
          hostname: 'discord.com'
          port: 443
          path: '/api/users/@me'
          headers:
            'Authorization': "#{data.token_type} #{data.access_token}"
        # console.log "meOptions:", meOptions
        meReq = https.request meOptions, (meRes) ->
          meRawJSON = ""
          meRes.on 'data', (chunk) ->
            meRawJSON += chunk
          meRes.on 'error', ->
            console.log "Error getting auth"
            resolve('')
          meRes.on 'end', ->
            meData = null
            try
              meData = JSON.parse(meRawJSON)
            catch
              console.log "ERROR: Failed to talk to parse JSON: #{meRawJSON}"
              resolve('')
              return

            # console.log "Me replied:", meData
            if meData? and meData.username? and meData.discriminator?
              tag = "#{meData.username}##{meData.discriminator}"
              if secrets.allowed? and not secrets.allowed[tag]
                console.log "ERROR: Discord user '#{tag}' is not in secrets.allowed, bailing"
                resolve('')
              else
                auth = database.newAuth(tag)
                resolve(auth.token)
            else
              console.log "ERROR: Giving up on new token, couldn't get username and discriminator:", meData
              resolve('')

        meReq.end()

    req.write(params)
    req.end()
    console.log "sending request:", postdata

oauthGet = (req, res) ->
  console.log "OAuth! ", req.query
  if req.query? and req.query.code?
    processOAuth(req.query.code).then (token) ->
      if token? and (token.length > 0)
        res.cookie('token', token, { maxAge: 1000 * 3600 * 24 * 30, httpOnly: true })
        res.redirect("/")
      else
        res.redirect('/auth')
  else
    res.redirect('/auth')

authMiddleware = (req, res, next) ->
  req.discordAuth = database.getAuth(req.cookies.token)
  if (req.path == '/auth') or (req.path == '/oauth')
    next()
    return
  if not req.discordAuth?
    res.redirect('/auth')
    return
  next()

authGet = (req, res) ->
  if req.query? and req.query.logout?
    database.clearAuth(req.cookies.token)
    res.clearCookie('token')
    res.redirect('/auth')
    return

  html = """
    <html>
    <head>
    <title>Comics Authentication</title>
    </head>
    <style>
    body {
      color: #ffffff;
      background-color: #111111;
      margin-top: 50px;
      text-align: center;
    }
    .hello {
      margin-bottom: 20px;
    }
    a {
      text-decoration: none;
      color: #aaffaa;
    }
    </style>
    <body>

  """

  if req.discordAuth?
    html += """
      <div class="hello">Hello, <span class="username">#{req.discordAuth.tag}!</span></div>
      <div class="actions">[ <a href=\"/\">Browse Comics</a> ] [ <a href="/auth?logout">Logout</a> ]</div>
    """
  else
    redirectURL = "#{secrets.url}/oauth"
    loginLink = "https://discord.com/api/oauth2/authorize?client_id=#{secrets.discordClientID}&redirect_uri=#{encodeURIComponent(redirectURL)}&response_type=code&scope=identify"
    html += """
      <div class="hello">In order to browse and rate comics (and remember your place in them), you must authenticate via Discord.</span></div>
      <div class="actions">
        [ <a href=\"#{loginLink}\">Login via Discord</a> ]
      </div>
    """

  html += """

    </body>
    </html>
  """
  res.send(html)

# ---------------------------------------------------------------------------------------
# Crackers Read

progressRespond = (manifest, req, res) ->
  progress =
    children: manifest.children
    page: {}

  dbProgress = database.getProgress(req.discordAuth)
  for dir, list of progress.children
    for e in list
      e.rating = 0
      if dbProgress.rating[e.dir]?
        e.rating = dbProgress.rating[e.dir]

      if e.type == 'comic'
        e.page = 0
        e.perc = 0
        if (e.pages > 0) and dbProgress.page[e.dir]?
          e.page = dbProgress.page[e.dir]

          e.perc = Math.min(100, Math.floor(100 * e.page / e.pages))
          if e.page == 1
            # On Deck
            e.perc = 1
          else if e.perc == 1
            # Not on deck, lie about percentage
            e.perc = 2
        progress.page[e.dir] = e.page
      else # e.type == 'dir'
        e.perc = 0
        e.rating = 0

        readPages = 0
        totalPages = 0
        ratingSum = 0
        ratingCount = 0
        issues = manifest.issues[e.dir]
        for issue in issues
          totalPages += issue.pages
          if dbProgress.page[issue.dir]?
            readPages += dbProgress.page[issue.dir]
          if dbProgress.rating[issue.dir]?
            ratingSum += dbProgress.rating[issue.dir]
            ratingCount += 1

        if ratingCount > 0
          e.rating = ratingSum / ratingCount

        if totalPages > 0
          e.perc = Math.min(100, 100 * readPages / totalPages)
          if readPages > 0
            # Don't allow a 0% on something you've read at least one page on
            e.perc = Math.max(1, e.perc)
          if readPages != totalPages
            # Don't allow a 100% on something you haven't completely read.
            e.perc = Math.min(99, e.perc)
          if readPages == 1
            # On deck
            e.perc = 1
          else if e.perc == 1
            # Not on deck, lie about percentage
            e.perc = 2

      # Check ignored
      for ignore of dbProgress.ignore
        d = e.dir
        if not d.match(/\/$/)
          d += "/"
        if d.indexOf(ignore) == 0
          e.perc = -1
          break

  res.contentType("progress.json")
  res.send(progress)

progressGet = (req, res) ->
  manifest = JSON.parse(fs.readFileSync("#{__dirname}/../root/server.crackers", "utf8"))
  progressRespond(manifest, req, res)

progressPost = (req, res) ->
  # console.log "progressPost: #{JSON.stringify(req.body)}"
  manifest = JSON.parse(fs.readFileSync("#{__dirname}/../root/server.crackers", "utf8"))
  if req.body?
    if req.body.ignore?
      database.toggleIgnore(req.discordAuth, req.body.ignore)
    else if req.body.dir? and req.body.rating?
      issues = findFlatIssues(manifest, req.body.dir)
      for issue in issues
        database.setRating(req.discordAuth, issue.dir, req.body.rating)
    else if req.body.mark? or req.body.unmark?
      dir = req.body.mark
      markRead = true
      if req.body.unmark?
        dir = req.body.unmark
        markRead = false
      issues = findFlatIssues(manifest, dir)
      for issue in issues
        if markRead
          database.setPage(req.discordAuth, issue.dir, issue.pages)
        else
          database.setPage(req.discordAuth, issue.dir, 0)
    else if req.body.dir? and req.body.page?
      database.setPage(req.discordAuth, req.body.dir, req.body.page)
  progressRespond(manifest, req, res)

# ---------------------------------------------------------------------------------------

main = (argv) ->
  secrets = JSON.parse(fs.readFileSync('secrets.json', 'utf8'))
  console.log "Secrets:"
  console.log JSON.stringify(secrets, null, 2)
  if not secrets.discordClientID or not secrets.discordClientSecret
    fatalError "Discord secrets missing!"

  database = new Database()
  if not database.load()
    fatalError "Failed to init database!"

  app = express()
  http = require('http').createServer(app)

  app.use(cookieParser())
  app.use authMiddleware
  app.use(express.json())
  app.get '/auth', authGet
  app.get '/oauth', oauthGet
  app.get '/progress', progressGet
  app.post '/progress', progressPost
  app.use(express.static('root'))

  host = '127.0.0.1'
  if argv.length > 0
    host = '0.0.0.0'
  http.listen 3003, host, ->
    console.log("listening on #{host}:3003")

module.exports = main

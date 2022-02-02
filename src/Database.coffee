fs = require 'fs'
util = require 'util'
writeFileAtomicSync = require('write-file-atomic').sync

randomString = ->
  return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15)

now = ->
  return Math.floor(Date.now() / 1000)

class Database
  constructor: ->
    @auth = {}
    @authSaveTimeout = null
    @progress = {}
    @progressSaveTimeout = null

  load: ->
    if fs.existsSync("auth.json")
      @auth = JSON.parse(fs.readFileSync("auth.json", 'utf8'))
    if fs.existsSync("progress.json")
      @progress = JSON.parse(fs.readFileSync("progress.json", 'utf8'))
    return true

  # -------------------------------------------------------------------------------------
  # Auth

  saveAuth: ->
    if not @authSaveTimeout?
      @authSaveTimeout = setTimeout =>
        @authSaveTimeout = null
        writeFileAtomicSync("auth.json", JSON.stringify(@auth, null, 2))
        util.log "Saved[Auth]."
      , 5000

  newAuth: (tag) ->
    loop
      newToken = randomString()
      if not @auth[newToken]?
        break
    util.log "Login [#{newToken}]: #{tag}"
    return @setAuth(newToken, tag)

  clearAuth: (token) ->
    if token? and @auth[token]?
      util.log "Logout [#{token}]: #{@auth[token].tag}"
      delete @auth[token]
      @saveAuth()

  setAuth: (token, tag) ->
    @auth[token] =
      token: token
      tag: tag
      added: now()
    @saveAuth()
    return @auth[token]

  getAuth: (token) ->
    if not token?
      return null
    auth = @auth[token]
    if not auth?
      return null
    return auth

  # -------------------------------------------------------------------------------------
  # Progress

  saveProgress: ->
    if not @progressSaveTimeout?
      @progressSaveTimeout = setTimeout =>
        @progressSaveTimeout = null
        writeFileAtomicSync("progress.json", JSON.stringify(@progress, null, 2))
        util.log "Saved[Progress]."
      , 5000

  toggleIgnore: (auth, dir) ->
    progress = @getProgress(auth, true)
    if progress.ignore[dir]?
      delete progress.ignore[dir]
    else
      progress.ignore[dir] = 1
    @saveProgress()
    return progress

  setPage: (auth, dir, page) ->
    progress = @getProgress(auth, true)
    progress.page[dir] = page
    if page < 1
      delete progress.page[dir]
    @saveProgress()
    return progress

  setRating: (auth, dir, rating) ->
    progress = @getProgress(auth, true)
    if rating > 0
      progress.rating[dir] = rating
    else if progress.rating[dir]?
      delete progress.rating[dir]
    @saveProgress()
    return progress

  getProgress: (auth, create = false) ->
    progress = @progress[auth.tag]
    if not progress?
      progress =
        tag: auth.tag
        page: {}
        ignore: {}
        rating: {}
    if create
      @progress[auth.tag] = progress
    return progress

  # -------------------------------------------------------------------------------------

module.exports = Database

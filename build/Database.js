// Generated by CoffeeScript 2.6.1
(function() {
  var Database, fs, now, randomString, util, writeFileAtomicSync;

  fs = require('fs');

  util = require('util');

  writeFileAtomicSync = require('write-file-atomic').sync;

  randomString = function() {
    return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
  };

  now = function() {
    return Math.floor(Date.now() / 1000);
  };

  Database = class Database {
    constructor() {
      this.auth = {};
      this.authSaveTimeout = null;
      this.progress = {};
      this.progressSaveTimeout = null;
    }

    load() {
      if (fs.existsSync("auth.json")) {
        this.auth = JSON.parse(fs.readFileSync("auth.json", 'utf8'));
      }
      if (fs.existsSync("progress.json")) {
        this.progress = JSON.parse(fs.readFileSync("progress.json", 'utf8'));
      }
      return true;
    }

    // -------------------------------------------------------------------------------------
    // Auth
    saveAuth() {
      if (this.authSaveTimeout == null) {
        return this.authSaveTimeout = setTimeout(() => {
          this.authSaveTimeout = null;
          writeFileAtomicSync("auth.json", JSON.stringify(this.auth, null, 2));
          return util.log("Saved[Auth].");
        }, 5000);
      }
    }

    newAuth(tag) {
      var newToken;
      while (true) {
        newToken = randomString();
        if (this.auth[newToken] == null) {
          break;
        }
      }
      util.log(`Login [${newToken}]: ${tag}`);
      return this.setAuth(newToken, tag);
    }

    clearAuth(token) {
      if ((token != null) && (this.auth[token] != null)) {
        util.log(`Logout [${token}]: ${this.auth[token].tag}`);
        delete this.auth[token];
        return this.saveAuth();
      }
    }

    setAuth(token, tag) {
      this.auth[token] = {
        token: token,
        tag: tag,
        added: now()
      };
      this.saveAuth();
      return this.auth[token];
    }

    getAuth(token) {
      var auth;
      if (token == null) {
        return null;
      }
      auth = this.auth[token];
      if (auth == null) {
        return null;
      }
      return auth;
    }

    // -------------------------------------------------------------------------------------
    // Progress
    saveProgress() {
      if (this.progressSaveTimeout == null) {
        return this.progressSaveTimeout = setTimeout(() => {
          this.progressSaveTimeout = null;
          writeFileAtomicSync("progress.json", JSON.stringify(this.progress, null, 2));
          return util.log("Saved[Progress].");
        }, 5000);
      }
    }

    toggleIgnore(auth, dir) {
      var progress;
      progress = this.getProgress(auth, true);
      if (progress.ignore[dir] != null) {
        delete progress.ignore[dir];
      } else {
        progress.ignore[dir] = 1;
      }
      this.saveProgress();
      return progress;
    }

    setPage(auth, dir, page) {
      var progress;
      progress = this.getProgress(auth, true);
      progress.page[dir] = page;
      if (page < 1) {
        delete progress.page[dir];
      }
      this.saveProgress();
      return progress;
    }

    setRating(auth, dir, rating) {
      var progress;
      progress = this.getProgress(auth, true);
      if (rating > 0) {
        progress.rating[dir] = rating;
      } else if (progress.rating[dir] != null) {
        delete progress.rating[dir];
      }
      this.saveProgress();
      return progress;
    }

    getProgress(auth, create = false) {
      var progress;
      progress = this.progress[auth.tag];
      if (progress == null) {
        progress = {
          tag: auth.tag,
          page: {},
          ignore: {},
          rating: {}
        };
      }
      if (create) {
        this.progress[auth.tag] = progress;
      }
      return progress;
    }

  };

  // -------------------------------------------------------------------------------------
  module.exports = Database;

}).call(this);

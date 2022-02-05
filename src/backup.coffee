fs = require 'fs'
path = require 'path'
{spawnSync} = require 'child_process'

main = (argv) ->
  opts = require('minimist')(argv, {
    boolean: ['v']
    alias:
      verbose: 'v'
  })

  rootDir = path.normalize(path.join(path.dirname(fs.realpathSync(__filename)), '..'))
  backupDir = path.normalize(path.join(path.dirname(fs.realpathSync(__filename)), '../backup'))
  if opts.verbose
    console.log "rootDir  : #{rootDir}"
    console.log "backupDir: #{backupDir}"

  if not fs.existsSync(backupDir)
    console.error "ERROR: Please create a valid github repo in #{backupDir}"
    return

  filesToBackup = []
  fileList = fs.readdirSync(rootDir)
  for filename in fileList
    parsed = path.parse(filename)
    if (parsed.ext == '.json') and not parsed.name.match(/^package/)
      filesToBackup.push filename

  for filename in filesToBackup
    src = path.normalize(path.join(rootDir, filename))
    dst = path.normalize(path.join(backupDir, filename))
    if opts.verbose
      console.log "Copy: #{src} -> #{dst}"
    fs.copyFileSync(src, dst)

  spawnOptions = {}
  if opts.verbose
    spawnOptions.stdio = 'inherit'
  originalCwd = process.cwd()
  process.chdir(backupDir)
  spawnSync('git', ['add', '.'], spawnOptions)
  spawnSync('git', ['commit', '-m', 'update'], spawnOptions)
  spawnSync('git', ['push'], spawnOptions)
  process.chdir(originalCwd)

module.exports = main

{CompositeDisposable} = require 'atom'
Os = require 'os'
Path = require 'path'
fs = require 'fs-plus'

git = require '../git'
notifier = require '../notifier'
splitPane = require '../splitPane'

nothingToShow = 'Nothing to show.'

disposables = new CompositeDisposable

showFile = (filePath) ->
  atom.workspace.open(filePath, searchAllPanes: true).then (textEditor) ->
    if atom.config.get('git-plus.openInPane')
      splitPane(atom.config.get('git-plus.splitPane'), textEditor)
    else
      textEditor

prepFile = (text, filePath) ->
  new Promise (resolve, reject) ->
    if text?.length is 0
      reject nothingToShow
    else
      fs.writeFile filePath, text, flag: 'w+', (err) ->
        if err then reject err else resolve true

module.exports = (repo, {diffStat, file}={}) ->
  diffFilePath = Path.join(repo.getPath(), "atom_git_plus.diff")
  file ?= repo.relativize(atom.workspace.getActiveTextEditor()?.getPath())
  if not file
    return notifier.addError "No open file. Select 'Diff All'."
  args = ['diff', '--color=never']
  args.push 'HEAD' if atom.config.get 'git-plus.includeStagedDiff'
  args.push '--word-diff' if atom.config.get 'git-plus.wordDiff'
  args.push file unless diffStat
  git.cmd(args, cwd: repo.getWorkingDirectory())
  .then (data) -> prepFile((diffStat ? '') + data, diffFilePath)
  .then -> showFile diffFilePath
  .then (textEditor) ->
    disposables.add textEditor.onDidDestroy -> fs.unlink diffFilePath
  .catch (err) ->
    if err is nothingToShow
      notifier.addInfo err
    else
      notifier.addError err

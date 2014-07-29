Path = require 'path'

module.exports = (robot) ->
  robot.loadFile(Path.resolve(__dirname, 'src'), "script.coffee")

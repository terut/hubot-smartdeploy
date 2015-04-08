# Description:
#   Deployment with pull request and deployments api on github
#

Path = require 'path'
Deployment = require(Path.join(__dirname, 'deployment')).Deployment

module.exports = (robot) ->
  robot.respond /deploy\s+status/i, (msg) ->
    Deployment.status(msg.robot, (text) ->
      msg.send text
    )

  robot.respond /deploy\s+status\s+clear/i, (msg) ->
    Deployment.clearStatus(msg.robot, (success) ->
      if success
        msg.send "Clear memory."
        # msg.send "Oops! something went wrong."
    )

  #robot.respond /deploy ((?:[a-z0-9_-]*\/)?[a-z0-9_-]*) to ([a-z0-9_-]*)/i, (msg) ->
  robot.respond /deploy\s+([^\s\:]+)(?:\:([^\s\:]+))?\s+to\s+([-_\.0-9a-z]+)(?:\s+#\s*([^\s\:]+))?/i, (msg) ->
    repo = msg.match[1]
    ref = msg.match[2]
    env = msg.match[3]
    comment = msg.match[4] or ""

    #delete @robot.brain.data.smartdeploy
    deployment = new Deployment(msg.robot, msg.envelope, repo, ref, env, comment)
    deployment.deploy (message, success) =>
      if success
        msg.send "@here #{message}"
      else
        msg.reply message


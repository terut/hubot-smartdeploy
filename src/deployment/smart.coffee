api = require('octonode').client(process.env.HUBOT_GITHUB_TOKEN or 'unknown')
api.requestDefaults.headers['Accept'] = 'application/vnd.github.cannonball-preview+json'

class SmartDeployment
  constructor: (@robot, @username, @repo, ref, @env, @required) ->
    @robot.brain.data.smartdeploy or= {}
    @robot.brain.data.smartdeploy[@env] or= {}

    @ref = ref or "master"
    host = @hostElection()
    @hostname = host['name']
    @url = host['url']
    @payload = @payload()

  run: (callback) ->
    path = "repos/#{@repo}/deployments"
    api.post path, @payload, (err, status, body, headers) =>
      if !err
        @memory()

      callback(err, body, headers)

  payload: ->
    payload = {}

    if @required['provider'] =='heroku'
      payload['url'] = @url
      payload['provider'] = @required['provider']
      payload['extension_payload'] = {
        app_name: @hostname
      }
    {
      ref: @ref,
      environment: @env,
      payload: payload
    }

  hostElection: ->
    data = @robot.brain.data.smartdeploy[@env]
    hosts = @hosts()

    unusedHosts = []
    for host, url of hosts
      unusedHosts.push { name: host, url: url } if !data[host]

    if unusedHosts.length > 0
      return unusedHosts[0]

    for key, val of data
      return { name: key, url: hosts[key] } if val['ref'] == @ref

    oldHost = null
    lastTime = null
    for key, val of data
      if lastTime == null || lastTime > val['time']
        lastTime = val['time']
        oldHost = key

    { name: oldHost, url: hosts[oldHost] }

  hosts: ->
    if @required['provider'] == 'heroku'
      hosts = @required['heroku_app_names']
    hosts or= {}

  memory: ->
    @robot.brain.data.smartdeploy[@env][@hostname] = {
      user: @username,
      time: new Date().getTime(),
      ref: @ref,
      url: @url
    }

  status: ->
    data = @robot.brain.data.smartdeploy

    status = ""
    for key1, val1 of data
      for key2, val2 of val1
        time = new Date(val2['time'])
        status += "#{key2}: deploy #{val2['ref']} at #{time} by #{val2['user']}\n  #{val2['url']}\n"
    status

exports.SmartDeployment = SmartDeployment

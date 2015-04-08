Fs = require 'fs'
Path = require 'path'
PullRequestDeployment = require(Path.join(__dirname, 'deployment/pull_request')).PullRequestDeployment
SmartDeployment = require(Path.join(__dirname, 'deployment/smart')).SmartDeployment

class Deployment
  @APPS_FILE = process.env['HUBOT_DEPLOY_APPS_JSON'] or  'deployment.json'

  @status: (robot, callback) ->
    SmartDeployment.status(robot, callback)

  @clearStatus: (robot, callback) ->
    SmartDeployment.clearStatus(robot, callback)

  constructor: (@robot, @envelope, @repo, @ref, @env, @comment) ->
    try
      applications = JSON.parse(Fs.readFileSync(@constructor.APPS_FILE).toString())
      @application = applications[@repo] or {}
    catch
      throw new Error('Unable to parse your deployment.json file in hubot.')

  deploy: (callback) ->
    if !@hasEnviroment()
      callback('Unable to deploy to unknown environment.', false)
      return

    if !@hasRequired()
      callback("You must set 'required' key in deployment.json.", false)
      return

    config = @config()
    username = @envelope.user.name

    switch config['type']
      when 'pull_request'
        room = @envelope.room || "Unknown"
        deployment = new PullRequestDeployment(username, room, @repo, @ref, @env, @required())

        if @isAutoMerge()
          deployment.runWithAutoMerge (err, data, headers) ->
            if err
              callback("Oops! #{err.message}.", false)
            else
              callback("Pull request is created and merged. Wait for shipping it.", true)
        else
          deployment.run (err, data, headers) ->
            if err
              callback("Oops! #{err.message}.", false)
            else
              message = "Pull request is created. Please check change log.\n#{data.html_url}"
              callback(message, true)
      when 'smart'
        deployment = new SmartDeployment(@robot, username, @repo, @ref, @env, @comment, @required())
        deployment.run (err, data, headers) ->
          if err
            callback("Unable to deploy with #{env}.", false)
          else
            callback("Deployments event is sent. Wait for shipping it.", true)
      else
        callback('Unable to deploy with unknown deployment type.', false)

  isAutoMerge: ->
    @config()['required']['auto_merge']

  hasEnviroment: ->
    @config() != null

  hasRequired: ->
    @required() != null

  required: ->
    @config()['required']

  config: ->
    @application[@env]

exports.Deployment = Deployment

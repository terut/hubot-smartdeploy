api = require('octonode').client(process.env.HUBOT_GITHUB_TOKEN or 'unknown')
api.requestDefaults.headers['Accept'] = 'application/vnd.github.v3+json'

class PullRequestDeployment
  constructor: (@username, @room, @repo, ref, @env, @required) ->
    @ref = ref or @required['ref']
    @payload = @payload()
    @log = null

  run: (callback) ->
    api.repo(@repo).pr(@payload, (err, data, headers) ->
      # err object already lost detail message, therefore it updates err.message
      if err
        err.message = "Creating pull request is failure."

      callback(err, data, headers)
    )

  runWithAutoMerge: (callback) ->
    @run (err, data, headers) =>
      if err
        callback(err, data, headers)
      else
        pr = api.pr(@repo, data.number)
        if data.mergeable
          pr.merge(@payload.title, callback)
        else
          waitMergeable = (perSec) =>
            @sleep perSec, => pr.info (err, data, headers) =>
                if err
                  callback(err)
                else
                  if data.mergeable == null
                    waitMergeable(10)
                  else if data.mergeable
                    pr.merge(@payload.title, callback)
                  else
                    callback(err, null, null)
          waitMergeable(10)

  sleep: (secs, cb) ->
    setTimeout cb, secs * 1000

  payload: ->
    time = require('time')
    now = new time.Date()
    now.setTimezone("Asia/Tokyo")

    title = "#{now.getFullYear()}.#{('0' + (now.getMonth() + 1)).slice(-2)}.#{('0' + now.getDate()).slice(-2)} #{@env} deployment by #{@username}"
    toBranch = @ref
    fromBranch = "master"
    body = "- Created by #{@username} on #{@room} Room (via hubot)\n- Discuss about release contents on this pull request"

    {
      title: title,
      head: fromBranch,
      base: toBranch,
      body: body
    }

exports.PullRequestDeployment = PullRequestDeployment

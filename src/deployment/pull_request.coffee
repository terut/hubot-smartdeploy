api = require('octonode').client(process.env.HUBOT_GITHUB_TOKEN or 'unknown')
api.requestDefaults.headers['Accept'] = 'application/vnd.github.v3+json'

class PullRequestDeployment
  constructor: (@username, @room, @repo, ref, @env, @required) ->
    @ref = ref or @required['ref']
    @payload = @payload()
    @log = null

  run: (callback) ->
    api.repo(@repo).pr(@payload, (err, data, headers) =>
      # err object already lost detail message, therefore it updates err.message
      if err
        err.message = "Creating pull request is failure."
      else
        @updatePullRequest(data.number, data.body)

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
    moment = require('moment')
    now = moment()

    title = "#{now.format("YYYY.MM.DD")} #{@env} deployment by #{@username}"

    toBranch = @ref
    fromBranch = "master"
    body = "- Created by #{@username} on #{@room} Room (via hubot)\n- Discuss about release contents on this pull request"

    {
      title: title,
      head: fromBranch,
      base: toBranch,
      body: body
    }

  updatePullRequest: (number, body) ->
    body += "\n\n### Changelog\n\n"

    pr = api.pr(@repo, number)
    rep = api.repo(@repo)
    pr.commits (err, data, headers) ->
      targetPrs = []
      for d in data
        # Merge pull request #199 from davia/feature/remove_halloween\n\nRemove halloween
        match = d.commit.message.match(/Merge pull request #([0-9]*) from .*\n\n(.*)/)
        unless match
          continue

        pullrequest = {
          number: match[1],
          title: match[2]
          author: d.author.login
        }
        targetPrs.push(pullrequest)

      rep.prs({state: 'closed'}, (err, data, headers) ->
        prs = {}
        for d in data
          text = ""
          if d.body
            line = d.body.split("\n")[0]
            if /https?:\/\//.test(line)
              text = line
            else
              text = d.title
          else
             text = d.title
          prs[d.number] = text

        for p in targetPrs
          body += "- ##{p.number} #{prs[p.number]} @#{p.author}\n"

        pr.update({
          'body': body
        }, (err, data, headers) ->
          if err
            console.log(err)
        )
      )

exports.PullRequestDeployment = PullRequestDeployment

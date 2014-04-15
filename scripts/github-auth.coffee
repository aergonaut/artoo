# Description:
#   Adds GitHub OAuth to Hubot
#
# Dependencies:
#   "express": "^3.0.0"
#
# Configuration:
#   GITHUB_CLIENT_ID
#   GITHUB_CLIENT_SECRET
#   HUBOT_SESSION_SECRET
#
# Commands:
#   hubot i am <login> on github - set your GitHub login
#   hubot who am i on github - ask Hubot what your GitHub login is
#
# URLs:
#   /auth/github
#   /auth/github/callback
#
# Author:
#   aergonaut

express = require 'express'

module.exports = (robot) ->

  robot.router.use express.cookieParser()
  robot.router.use express.session
    secret: process.env.HUBOT_SESSION_SECRET

  ClientId = process.env.GITHUB_CLIENT_ID
  ClientSecret = process.env.GITHUB_CLIENT_SECRET

  robot.router.get "/auth/github", (req, res) ->
    state = require('crypto').randomBytes(48).toString('hex')
    scope = 'user:email,read:org,repo_deployment'
    req.session.githubAuthState = state
    res.redirect "https://github.com/login/oauth/authorize?client_id=#{ClientId}&state=#{state}&scope=#{scope}"

  robot.router.get "/auth/github/callback", (req, res) ->
    clientState = req.session.githubAuthState
    receivedState = req.query.state
    req.session.state = null

    # if !clientState?
    #   res.redirect "/auth/github"
    #   return

    if clientState != receivedState
      res.end "The received state didn't match the state in your session!"
      return

    code = req.query.code

    robot.http("https://github.com/login/oauth/access_token?client_id=#{ClientId}&client_secret=#{ClientSecret}&code=#{code}").header("Accept", "application/json").post() (err, resp, body) ->
      auth_hash = JSON.parse(body)
      token = auth_hash["access_token"]

      robot.http("https://api.github.com/user").header("Authorization", "token #{token}").header("Accept", "application/json").get() (err, resp, body) ->
        user_hash = JSON.parse(body)

        user_info =
          auth: auth_hash
          user: user_hash

        githubUsers = robot.brain.get "githubUsers"
        githubUsers ?= {}
        githubUsers[user_hash.login] = user_info

        robot.brain.set "githubUsers", githubUsers

  robot.respond /i am (.*) on github/i, (msg) ->
    login = msg.match[1].trim()
    msg.message.user.githubLogin = login
    name = msg.message.user.name
    response = "OK, you're #{login} on GitHub."
    if !robot.brain.get("githubUsers")[login]?
      response = "#{response} It doesn't look I have your auth token yet. Please visit https://glacial-plains-1225.herokuapp.com/login and authorize me when you get the chance."
    msg.reply response

  robot.respond /who am i on github/i, (msg) ->
    login = msg.message.user.githubLogin
    msg.reply "You are #{login} on GitHub."

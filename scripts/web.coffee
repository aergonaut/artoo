# Description:
#   Web routes for hubot

module.exports = (robot) ->
  
  robot.router.set 'view engine', 'ejs'
  
  robot.router.get "/login", (req, res) ->
    res.render 'login.ejs'

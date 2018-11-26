require './talk_to_me'

$stdout.sync = true # make sure to show logs when running heroku local web
run Sinatra::Application

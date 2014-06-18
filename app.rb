require 'rubygems'
require 'sinatra'
require 'sinatra/reloader' if development?

set :server, 'thin'
set :port, 2424

get '/' do
  "ride trains"
end

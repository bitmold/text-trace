require 'sinatra'
require 'sinatra/reloader' if development?

set :server, 'thin'

get '/' do
  "ride trains"
end

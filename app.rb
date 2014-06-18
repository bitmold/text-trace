require 'rubygems'
require 'bundler/setup'
Bundler.require(:default, :development)

require 'sinatra/reloader' if development?

set :server, 'thin'
set :port, 2424

get '/' do
  erb :index
end
  twiml = Twilio::TwiML::Response.new do |response|
    response.Message "ride trains!"
  end
  twiml.text
end

require 'rubygems'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'twilio-ruby'

set :server, 'thin'
set :port, 2424

get '/' do
  twiml = Twilio::TwiML::Response.new do |response|
    response.Message "ride trains!"
  end
  twiml.text
end

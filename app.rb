require 'rubygems'
require 'bundler/setup'
Bundler.require(:default, :development)

if development?
  require 'dotenv'; Dotenv.load
  require 'sinatra/reloader'
end

set :server, 'thin'

configure do
  set :BNSF_TRACE_URI, ENV['BNSF_TRACE_URI']
  set :VALID_CONTAINER_NUMBER_REGEX, /[a-z]{3}u\d{6,}/i

  set :client, Redis.new(url: ENV['REDIS_URL'])
  set :cache, Proc.new { Cache.wrap(client).tap { |c| c.config.default_ttl = 1800 } }
end

helpers do
  def trace(container_number)
    response = @cache.fetch "trace:bnsf:#{container_number}" do
      r = Typhoeus.post([settings.BNSF_TRACE_URI, container_number].join)
      raise "The trace was not successful (#{container_number})." unless r.success?; r
    end

    doc = Nokogiri::HTML(response.body)
    
    destination = doc.css("span#DestHub").inner_html
    eta = doc.css("span#ETA").inner_html

    raise "The trace did not return a destination (#{container_number})." unless destination

    { destination: destination, eta: eta }
  end

  def trace_result(container_number, destination, eta)
<<-MESSAGE
Container Number: #{container_number}
Destination: #{destination}
ETA: #{eta}
MESSAGE
  end

  def twiml_response(message)
    Twilio::TwiML::Response.new { |r| r.Message message }.text
  end
end

before do
  @cache = settings.cache
end

post '/trace' do
  query = params[:Body]
  valid_container_number_regex = settings.VALID_CONTAINER_NUMBER_REGEX

  unless container_number = valid_container_number_regex.match(query)[0]
    return twiml_response "Invalid container number: The container number should have format XXXU1234567"
  end

  begin
    result = trace(container_number)
  rescue => exception
    return twiml_response exception.message
  end

  message = trace_result(container_number, result[:destination], result[:eta])
  twiml_response message
end

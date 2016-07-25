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
  set :BNSF_TRACE_ETA_FORMAT, "%m/%d/%Y  %H%M".freeze
  set :VALID_CONTAINER_NUMBER_REGEX, /[a-z]{3}u\d{6,}/i

  set :invalid_container_number_message, "Invalid container number: The container number should have format XXXU1234567".freeze

  set :client, Redis.new(url: ENV['REDIS_URL'])
  set :cache, Proc.new { Cache.wrap(client).tap { |c| c.config.default_ttl = 1800 } }
end

helpers do
  def trace(container_number)
    response = @cache.fetch "trace:bnsf:#{container_number}" do
      r = Typhoeus.post([settings.BNSF_TRACE_URI, container_number].join)
      raise "The trace was not successful (#{container_number.upcase})." unless r.success?; r
    end

    doc = Nokogiri::HTML(response.body)
    
    destination = doc.css("span#DestHub").inner_html
    eta = doc.css("span#ETA").inner_html

    unless destination and not destination.empty?
      raise "The trace did not return a destination (#{container_number.upcase})."
    end

    { destination: destination, eta: eta }
  end

  def trace_result(container_number, destination, eta)
<<-MESSAGE
Container Number: #{container_number.upcase}
Destination: #{destination}
ETA: #{format_eta eta}
MESSAGE
  end

  def format_eta(eta)
    Time.strptime(eta, settings.BNSF_TRACE_ETA_FORMAT).strftime("%m/%d/%y at%l:%M%p") unless eta.strip.empty?
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

  if match = valid_container_number_regex.match(query)
    container_number = match[0]
  end
  return twiml_response settings.invalid_container_number_message unless container_number

  begin
    result = trace(container_number)
  rescue => exception
    return twiml_response exception.message
  end

  message = trace_result(container_number, result[:destination], result[:eta])
  twiml_response message
end

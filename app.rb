require 'rubygems'
require 'bundler/setup'
Bundler.require(:default, :development)

require 'sinatra/reloader' if development?

set :server, 'thin'
set :port, 2424

get '/' do
  erb :index
end

get '/trace' do
  query = params[:Body]
  bnsf_trace(query)
  twiml = Twilio::TwiML::Response.new do |response|
    response.Message "container id: #{query}\ndestination: #{@destination}\neta: #{@eta}"
  end
  twiml.text
end

def bnsf_trace(query)
  response = Typhoeus.post('http://m.bnsf.com/bnsf.was6/dillApp/rprt/QRYM?selectedValues=&spoolId=&cmd=&patName=&patAddress=&patAddress2=&patCity=&patState=&patAttn=&patZip=&patPhone=&selectStation=&hEqpInit=&hEqpNumb=&selTotal=&equipment=' + query)
  doc = Nokogiri::HTML(response.body)
   
  @destination = doc.css("span#DestHub").inner_html
  @eta = doc.css("span#ETA").inner_html
end
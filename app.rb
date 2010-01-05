require 'rubygems'
require 'sinatra'
require 'json'
require 'nokogiri'
require 'net/http'
require 'open-uri'

require 'data_mapper'

DataMapper.setup(:default, ENV['DATABASE_URL'] || "mysql://root:t3xtmat3@localhost:3306/test")

class ZipCode
  include DataMapper::Resource

  property :zip_code, Integer
  property :lat, Float
  property :lon, Float

  storage_names[:default] = 'zip_code'
end



get "/" do
  redirect "index.html"
end

get '/codes' do

  doc = Nokogiri::HTML(open('http://www.insideredbox.com/redbox-codes/'))

  @codes = []

  # table#codelist tbody tr
  doc.css('#codelist span.codelink').each do |code|
    @codes << code.content
  end

  erb :codes
end

post '/locations' do

  puts params[:zip].to_s + '------'

  if params[:zip].to_s.length > 0
    zip_code = ZipCode.first(:zip_code => params[:zip])
    params[:lat] = zip_code.lat
    params[:long] = zip_code.lon
  end

  results = search(params[:lat], params[:long])

  if results.has_key? 'd'
    @locations = results['d']['profiles']
  else
    @locations = []
  end

  erb :locations
end

def search(lat, long)
  url = "/ajax.svc/Kiosk/GetNearbyKiosks"

  params =  {
              "latitude" => lat, "longitude" => long,
              "radius" => 50, "maxKiosks" => 50, "mcdOnly" => false,
              "getInv" => false, "pageSize" => 20, "page" => 1,
              "__K" => "UNKNOWN"
            }

  headers = {
    'Host'       => "www.redbox.com",
    'User-Agent' => "Rubies",
    'Referer'    => "http://www.redbox.com/Locations/LocationSearch.aspx",
    'Content-Type' => 'application/json; charset=utf-8'
  }

  http = Net::HTTP.new('www.redbox.com')

  data = http.start do |net|
    net.request_post(url, params.to_json, headers) do |response|
      data = {}
      if response.is_a? Net::HTTPSuccess
        data = JSON.parse(response.body)
      else
        data = {:error => "Couldn't contact server"}
      end
    end
    data
  end
end
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
end



get "/" do
  redirect "index.html"
end

get '/codes' do
  doc = Nokogiri::HTML(open('http://www.insideredbox.com/redbox-codes/'))

  @codes = []

  # table#codelist tbody tr
  doc.css('#codelist td.code_listing').each do |row|
    info = Hash.new
    info[:status]  = determine_color(row.at_css(".code_status img")['src'])

    next if info[:status] == 'expired'

    info[:code]    = row.at_css(".code_code").content.strip unless row.at_css(".code_code").nil?

    next if info[:code].to_s == ''

    info[:special] = row.at_css(".code_special").content.strip unless row.at_css(".code_special").nil?
    info[:date]    = row.at_css(".code_lastuse").content.strip unless row.at_css(".code_lastuse").nil?

    if info[:date].match(/(\d{2}\/\d{2}\/\d{2})/)
      info[:date] = $1.strip
    end

    info[:purpose] = row.at_css(".code_purpose").content.strip unless row.at_css(".code_purpose").nil?
    @codes << info
  end

  erb :codes
end

post '/locations' do
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
  params =  {
              "latitude" => lat, "longitude" => long,
              "radius" => 50, "maxKiosks" => 50, "mcdOnly" => false,
              "getInv" => false, "pageSize" => 20, "page" => 1,
              "__K" => "UNKNOWN"
            }

  headers = {
    'Host'       => "www.redbox.com",
    'User-Agent' => "Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_6_2; en-us) AppleWebKit/533.1+ (KHTML, like Gecko) Version/4.0.4 Safari/531.21.10",
    'Origin'     => "http://www.redbox.com",
    'Referer'    => "http://www.redbox.com/Locations/LocationSearch.aspx",
    'Content-Type' => 'application/json; charset=utf-8'
  }

  http = Net::HTTP.new('www.redbox.com')
  path = '/Locations/LocationSearch.aspx'
  resp, data = http.get(path, nil)
  cookie = resp.response['set-cookie'].split(';')[0]
  headers['Cookie'] = cookie

  doc = Nokogiri::HTML(resp.body.to_s)
  k = doc.at_css("#__K")['value']
  params['__K'] = k

  data = http.start do |net|
    path = "/ajax.svc/Kiosk/GetNearbyKiosks"
    net.request_post(path, params.to_json, headers) do |response|
      data = {}
      if response.is_a? Net::HTTPSuccess
        data = JSON.parse(response.body)
      else
        data = {:error => "Couldn't contact server", :response => response}
      end
    end
    data
  end
end

def determine_color(img)
  case img
  when /green/
    'new'
  when /red/
    'expired'
  else
    'unknown'
  end
end
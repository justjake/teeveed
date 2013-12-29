require 'rubygems'
require 'bundler'
Bundler.setup

require 'teevee'
require 'sinatra'
require 'haml'

require 'JSON'
wit = Teevee::Wit.new

HOMEPAGE = %(
!!! 5
%html
  %head
    %title teeveed
    %meta(name="viewport" content="width=device-width")
  %body
    %form(action="" method="post")
      %h2 Ask
      %textarea(name="q" style="width: 100%;")
      %input(type="submit" name="send")
)

RESP = HOMEPAGE + %(
    %div
      %h2 Receive
      %pre
        %code
          = @wit_json
)

puts "loading webapp"

set :bind, '0.0.0.0'
set :port, 1337

get '/' do
  haml HOMEPAGE
end

post '/' do
  @wit_json = JSON.pretty_generate(
      wit.message(
          params[:q]))
  haml RESP
end

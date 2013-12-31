require 'sinatra/base'
require 'haml'
require 'JSON'

module Teevee
  module Daemon

    # Web-based remote control interface for requesting actions
    # right now all it does is pass a <textarea> to Wit.ai
    class Remote < Sinatra::Base
      ### SETTINGS
      set :bind, REMOTE_IP
      set :port, REMOTE_PORT

      ### TEMPLATES
      # default template
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

      # template showing a response, too
      RESP = HOMEPAGE + %(
    %div
      %h2 Receive
      %pre
        %code
          = @intent_json
)
      template :index do
        HOMEPAGE
      end

      template :response do
        RESP
      end

      ### HTTP HANDLERS

      get '/' do
        haml HOMEPAGE
      end

      post '/' do
        wit = Teevee::Wit.new(WIT_ACCESS_TOKEN)
        @intent = wit.message(params[:q])
        @intent_json = JSON.pretty_generate(@intent)

        # TODO: dispatch on @intent

        haml RESP
      end
    end

  end
end

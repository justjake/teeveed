# -*- encoding : utf-8 -*-
require 'sinatra/base'
require 'haml'

# Core plugin.
# receives text from users via their smartphones, and then
# converts that text into Wit intents to feed to an IntentController
# All user interaction starts and ends in this plugin (for now ;)

module Teevee
  module Plugins
    class WebIU < Teevee::Plugin::Base
      # @param app [Teevee::Application]
      # @param opts [Hash] options
      # @option opts :ip [String] IP address to listen on
      # @option opts :port [Integer] port to listen on
      def initialize(app, opts)
        super(app, opts)
        if not (opts.include? :ip and opts.include? :port and opts.include? :wit_token)
          raise ArgumentError, 'WebUI options must include :ip, :port, and :wit_token'
        end

        # pass on everything to the Sinatra app.
        Server.set :app, app
        Server.set :bind, opts[:ip]
        Server.set :port, opts[:port]
        Server.set :wit_token, opts[:wit_token]
      end

      def run!
        Server.run!
      end

      # Web-based remote control interface for requesting actions
      # right now all it does is pass a <textarea> to Wit.ai
      class Server < Sinatra::Base
        helpers do
          def h(text)
            Rack::Utils.escape_html(text)
          end
        end

        ### TEMPLATES
        # default template
        HOMEPAGE = %q(
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
        RESP = HOMEPAGE + %q(
    %div
      %h2 Intent
      %pre
        %code
          = @intent_codez
      - if @intent_res
        %h2 Result
        = @intent_res
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
          wit = Teevee::Wit::API.new(settings.wit_token)
          controller = Teevee::IntentController.new(settings.app)

          @query = wit.query(params[:q])
          @intent_codez = h @query.pretty_inspect
          @intent_res = nil
          if @query.outcome.is_a? Wit::Intent
            begin
              @intent_res = controller.handle_intent(@query.outcome)
              @intent_res = h @intent_res.pretty_inspect
            rescue UnknownIntent => err
              @intent_res = "UnknownIntent: #{err.to_s}"
            rescue Unimplemented => err
              @intent_res = 'Unimplemented.'
            end
          end

          haml RESP
        end
      end # end Server
    end # end WebUI plugin


  end
end

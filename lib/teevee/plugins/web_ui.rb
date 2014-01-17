# -*- encoding : utf-8 -*-
require 'pp' # needed for #pretty_inspect
require 'sinatra/base'
require 'haml'

# Core plugin.
# receives text from users via their smartphones, and then
# converts that text into Wit intents to feed to an IntentController
# All user interaction starts and ends in this plugin (for now ;)

module Teevee
  module Plugins
    class WebUI < Teevee::Plugin::Base
      # @param app [Teevee::Application]
      # @param opts [Hash] options
      # @option opts :ip [String] IP address to listen on
      # @option opts :port [Integer] port to listen on
      def initialize(app, opts)
        super(app, opts)
        if not (opts.include? :ip and opts.include? :port)
          raise ArgumentError, 'WebUI options must include :ip and :port'
        end

        raise ArgumentError, "#{self.class.to_s} requires a wit_token" if app.wit_token.nil?

        # pass on everything to the Sinatra app.
        Server.set :app, app
        Server.set :bind, opts[:ip]
        Server.set :port, opts[:port]
        Server.set :wit_token, app.wit_token
      end

      def run!
        Server.run!
      end

      # Web-based remote control interface for requesting actions
      # right now all it does is pass a <textarea> to Wit.ai
      class Server < Sinatra::Base

        set :root, File.join(File.dirname(__FILE__), 'web_ui_files')
        set :server, :puma

        helpers do
          def escape_html(text)
            Rack::Utils.escape_html(text)
          end
        end


        ### HTTP HANDLERS

        get '/' do
          haml :index
        end

        get '/styles' do
          scss :stylesheet
        end

        post '/' do
          wit = Teevee::Wit::API.new(settings.wit_token)
          controller = Teevee::IntentController.new(settings.app)

          query = wit.query(params[:q])
          res = nil
          if query.outcome.is_a? Wit::Intent
            begin
              res = controller.handle_intent(query.outcome)
            rescue UnknownIntent => err
              res = "UnknownIntent: #{escape_html(err.message)}"
            rescue Unimplemented => err
              res = 'Unimplemented.'
            end
          end

          haml :index, :locals => {
              :query => escape_html(query.pretty_inspect),
              :result => escape_html(res.pretty_inspect)
          }
        end
      end # end Server
    end # end WebUI plugin


  end
end

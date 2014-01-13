# -*- encoding : utf-8 -*-
require 'sinatra/base'
require 'haml'

module Teevee
  module Daemon

    # Web-based remote control interface for requesting actions
    # right now all it does is pass a <textarea> to Wit.ai
    class WebRemote < Sinatra::Base
      helpers do
        def h(text)
          Rack::Utils.escape_html(text)
        end
      end

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
        wit = Wit::API.new(Daemon.instance.options[:wit_token])
        controller = Teevee::Daemon::IntentController.new(Teevee::Daemon.instance)

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
    end

  end
end

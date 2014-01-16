# -*- encoding : utf-8 -*-
# Debug the running teeveed instancw with 'pry-remote'
require 'pry-remote'

module Teevee
  module Plugins
    class RemoteDebugger < Teevee::Plugin::Base

      def run!
        while true do
          binding.pry_remote
        end
      end

      def run_local
        binding.pry
      end

      ### conventince methods for the remote-debugging user

      def plugins
        @app.plugins
      end

      def root
        app.root
      end

      def indexer
        app.indexer
      end

      def options
        app.options
      end

      def scheduler
        app.scheduler
      end

      # relies on the WebUI being loaded
      # TODO central place to store :wit_token
      def wit
        Wit::API.new(app.wit_token)
      end

      def gen_intent_controller
        IntentController.new(app)
      end

    end
  end
end

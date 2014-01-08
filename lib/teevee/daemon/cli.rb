require 'pry-remote'

module Teevee
  module Daemon

    # Access to an instance via a ruby interpreter
    # uses pry-remote
    class CLI

      attr_reader :app
      attr_accessor :api

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

      attr_accessor :store

      def initialize(app)
        @app = app
        @api = Wit::API.new(app.options[:wit_token])
      end

      def interact!
        binding.pry
      end

      def interact_remote!
        binding.pry_remote
      end
    end

  end
end
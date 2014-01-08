module Teevee

  # The daemon module uses the rest of the Teevee library to generate and respond
  # to media requests, update a library, etc.
  # it should eventually be totally configurable from a single DSL config file
  module Daemon

    def self.instance=(app)
      @app_instance = app
    end

    def self.instance
      @app_instance
    end

    class Application
      attr_reader :root, :indexer, :vlc, :options

      def initialize(root, indexer, opts)
        @root = root
        @indexer = indexer
        @vlc = VLC::System.new('127.0.0.1', 9999, auto_start: false)
        @options = opts
      end
    end # end Application

  end

end

require 'teevee/daemon/intent_controller'
require 'teevee/daemon/cli'
require 'teevee/daemon/web_remote'
require 'teevee/daemon/runner'

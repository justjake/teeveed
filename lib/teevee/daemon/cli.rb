require 'pry-remote'

module Teevee
  module Daemon

    # Access to an instance via a ruby interpreter
    # uses pry-remote
    class CLI

      attr_reader :root, :wit
      attr_accessor :store

      def initialize
        @wit = Wit.new(WIT_ACCESS_TOKEN)
        @root = Library::Root.new(TEEVEED_HOME + 'library', Library::Sections)
      end

      def data
        'library/Movies/The Incredibles (2008).mkv'
      end

      def say(msg)
        @wit.message(msg)
      end

      def index(path)
        @root.index_path(path)
      end

      def interact!
        binding.pry_remote
      end
    end

  end
end
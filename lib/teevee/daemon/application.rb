module Teevee
  module Daemon

    # global storage
    class Application
      attr_reader :root, :indexer, :logger, :vlc

      def initialize(root, indexer, logger, vlc)
        @root = root
        @indexer = indexer
        @logger = logger
        @vlc = vlc
      end
    end

  end
end
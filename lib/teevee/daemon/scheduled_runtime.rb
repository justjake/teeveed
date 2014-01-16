# -*- encoding : utf-8 -*-
module Teevee
  module Daemon
    # the scope in which users scheduled actions are run
    class ScheduleRuntime
      def initialize(app)
        @app = app
      end

      # intended for scheduling index sweeps
      # @param path [String] relative to root, or an absolute path
      def scan_for_changes(path)
        path = Pathname.new(path)
        path = @app.root.pathname + path if path.relative?
        app.indexer.scan(path)
      end

      # destroy everything and start over
      def rebuild_index
        Teevee::Library::Media.all.destroy
        scan_for_changes(@app.root.path)
      end

      # log an event
      # @param level [Integer] log level
      # @param texts [Array<String>] things to say
      def log(level, *texts)
        Teevee.log(level, 'scheduled action', *texts)
      end
    end
  end
end

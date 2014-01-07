require 'listen'

module Teevee
  module Library

    # handles index building, change scanning, etc
    class Indexer
      attr_reader :change_proc
      attr_reader :root
      attr_reader :listeners

      DEFAULT_LISTENER_OPTIONS = {
          latency: 10,
          debug: true
      }.freeze

      # defines a method that is run for all listeners
      def self.listener_method(meth_name, &block)
        define_method(:meth_name) do
          @listeners.each(&block)
        end
      end

      # @param root [Root] we will manage index creation for this library root
      # @param section_opts [Hash<String, Hash>] map between library section
      #   prefixes (like "Movies")and options to the Listener for those sections.
      # @see https://github.com/guard/listen#options
      def initialize(root, section_opts = {})
        @root = root
        @change_proc = Proc.new do |modified, added, removed|
          added.each {|f| self.root.index_path(f)}
          removed.each {|f| self.root.remove_path(f)}
        end

        @listeners = _init_listeners(section_opts)
      end


      # start all directory-change listeners
      def start
        @listeners.each {|k,v| v.start}
      end

      # stop all directory-change listeners
      def stop
        @listeners.each {|k,v| v.stop}
      end

      # Do a find on `path`. Update the last_seen properties of all found items
      # delete all items that start with that path who's last seen is too old
      def scan(full_path)
        start_time = DateTime.now

        items = root.index_recursive(full_path)

        # add/update transaction
        Media.transaction do
          items.each do |file|
            in_db = Media.first(:relative_path => file.relative_path)
            if in_db # already indexed once, just update the date and save it
              in_db.last_seen = file.last_seen
              in_db.save
            else # new file, just add it to the DB!
              file.save
            end
          end
        end

        # old items
        in_scan = Media.all(:relative_path.like => root.relative_path(full_path)+'%')
        stale = in_scan.all(:last_seen.lt => start_time)
        Media.transaction do
          stale.destroy
        end
      end


      private

      def options_for_section(media_class)
        { :only => media_class.suffix }
      end

      def _init_listeners(sect_opts)
        listeners = {}
        self.root.sections.each do |path, section|
          opts = DEFAULT_LISTENER_OPTIONS.merge(sect_opts[path] || {})
            .merge(options_for_section(section) || {})
          listeners[path] = Listen.to((root.pathname+path).to_s, opts, &@change_proc)
        end
        listeners
      end

    end

  end
end
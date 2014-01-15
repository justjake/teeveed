# -*- encoding : utf-8 -*-
module Teevee
  module Library

    # handles index building, change scanning, etc
    class Indexer
      attr_reader :root

      class ScanResults
        attr_reader :created, :updated, :deleted
        def initialize(cr, up, del)
          @created = cr
          @updated = up
          @deleted = del
        end
      end

      # @param root [Root] we will manage index creation for this library root
      # @param section_opts [Hash<String, Hash>] map between library section
      #   prefixes (like "Movies")and options to the Listener for those sections.
      # @see https://github.com/guard/listen#options
      def initialize(root)
        @root = root
      end

      # Do a find on `path`. Update the last_seen properties of all found items
      # delete all items that start with that path who's last seen is too old
      # this breaks in strange ways if any Integer properties are provided as strings
      # (eg, '02' instead of 2)... which leads to silent save failures, etc
      def scan(full_path)
        start_time = Teevee::Library.rough_time

        items = root.index_recursive(full_path)

        created = []
        updated = []

        items.each do |file|
          Media.db.transaction do
            log 5, "checking file #{file.relative_path}"
            in_db = Media.find(:relative_path => file.relative_path)

            # already indexed once, just update the date and save it
            if in_db
              log 5, "\tOLD: #{file.relative_path} already in index, updating :last_seen"
              in_db.last_seen = Teevee::Library.rough_time
              updated << in_db
              in_db.save

            # new file, just add it to the DB!
            else
              log 5, "\tNEW: #{file.relative_path} new, saving for first time."
              created << file
              file.save
            end
          end
        end

        # old items
        in_scan = Media.where(:relative_path.like(root.relative_path(full_path) + '%'))
        log 5, "pruning: found #{in_scan.count} files under scan path in the index"
        stale = in_scan.where{last_seen < start_time}
        log 4, "pruning: found #{stale.count} stale files"

        deleted = stale.to_a
        # .delete is faster, but may not honor triggers:
        # see http://sequel.jeremyevans.net/rdoc/classes/Sequel/Model/DatasetMethods.html
        # we don't use any triggers right now!
        stale.destroy

        log 3, "scan finished: #{created.length} new, #{updated.length} old, #{deleted.length} deleted"
        ScanResults.new(created, updated, deleted)
      end

      private

      def log(level, *texts)
        Teevee.log(level, 'indexer', *texts)
      end

    end

  end
end

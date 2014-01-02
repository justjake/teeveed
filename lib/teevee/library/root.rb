require 'set'
require 'pathname'

module Teevee
  module Library

    # Oops - the path supplied is outside of the library root
    class PathError < StandardError; end

    # A single library containing lots of media
    # all media paths are stored relative to a root, so that multiple
    # systems mounting the same share to various mount points can look at a thing
    # and all agree that everything is in the same place
    class Root

      # sections is a Hash mapping from a relative path to a subclass of Media
      # intended to index the files in that path.
      # For instance, if you stored music videos in "/mnt/storage/Music Videos"
      # and your library root was "/mnt/storage", then your map should contain
      # "Music Videos" => Library::MusicVideo
      attr_reader :sections

      # root path
      attr_reader :pathname

      # root path as a Pathname
      def path
        self.pathname.to_s
      end

      def initialize(path, sections = {})
        @pathname = Pathname.new(path).realpath.freeze
        @sections = sections
      end

      # True if the given path is in this root
      # TODO: this is broken and does not enforce the constraint
      #   FIXIT
      def in_root?(path)
        fp = Pathname.new(path).realpath
        return true if fp.relative_path_from(self.pathname)
      rescue ArgumentError
        return false
      end

      # TODO replace with an exception type
      def path_not_under_error(other_path)
        raise PathError, "Path #{other_path} not under root #{self.to_s}"
      end

      # Returns path as relative to this root
      # @return String
      def relative_path(full_path)
        full_path = Pathname.new(full_path).realpath
        full_path.relative_path_from(self.pathname).to_s
      end

      # index a file into the library. basic algorithm:
      #   1. is this path within the Root?
      #   2. for each @sections:
      #     - does this path go in this section?
      #     - does this path have the right extension?
      #     - is this path already in the database?
      #     - cool, import using section.new section.regex.match(relative_path)
      # TODO: log all import operations
      def index_path(full_path)
        # only files that exist
        fp = Pathname.new(full_path).realpath

        # only files
        unless fp.file?
          raise TypeError, "The object at path #{fp} is not a file."
        end

        # fp must be in root
        unless in_root? fp
          path_not_under_error fp
        end

        rp = fp.relative_path_from(self.pathname).to_s
        prefix = @sections.keys.find {|prefix| rp.start_with? (prefix + '/') }

        @sections[prefix].index_path(rp, prefix)
      end

      # indexes all files in path, recursivley
      # @param start [String, Pathname] start of directory traversal
      def index_recusive(start)
        # check start is a good path.
        start = Pathname.new(start).realpath
        path_not_under_error(start.to_s) unless in_root? start

        indexed = []
        start.find do |path|
          next unless path.file?
          repr = self.index_path(path)
          indexed << repr if repr
        end
        indexed
      end

      # remove a path from the index
      def remove_path(full_path)
        full_path = Pathname.new(full_path).realpath.to_s
        unless in_root? full_path
          path_not_under_error full_path
        end

        rp = relative_path(full_path)
        repr = Media.first(:relative_path => rp)
        repr.delete!
      end
    end

  end
end
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
      def in_root?(path)
        fp = Pathname.new(path).realpath
        fp.to_s.start_with? self.path
      end

      # TODO replace with an exception type
      def path_not_under_error(other_path)
        raise PathError, "Path #{other_path} not under root #{self.to_s}"
      end

      # Returns path as relative to this root
      # @return String
      def relative_path(full_path)
        full_path = Pathname.new(full_path).realpath
        path = full_path.relative_path_from(self.pathname).to_s

        # we don't want the dot because we never save any dots
        if path == '.'
          return ''
        end

        return path
      end

      def section_for_path(full_path)
        fp = Pathname.new(full_path).realpath
        rp = relative_path(fp).to_s
        @sections.keys.find {|prefix| rp.start_with? (prefix + '/') }
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

        rp = relative_path(fp).to_s

        section = section_for_path(full_path)
        if section
          @sections[section].index_path(rp, section)
        end
      end

      # list of full paths of all the sections
      def section_paths
        @sections.keys.map {|k| (pathname + k).to_s}
      end

      def abs_path(rel)
        (pathname + rel).to_s
      end

      # indexes all files in path, recursivley
      # @param start [String, Pathname] start of directory traversal
      def index_recursive(start)
        # check start is a good path.
        start = Pathname.new(start).realpath
        path_not_under_error(start.to_s) unless in_root? start

        indexed = []

        start.find do |path|
          if in_root? path or section_paths.include? path.to_s
            # only index files
            next unless path.file?

            repr = self.index_path(path)
            indexed << repr if repr
          else
            Find.prune
          end
        end

        indexed
      end
    end

  end
end
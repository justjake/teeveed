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

      # root path
      attr_reader :path

      def initialize(path, sections = [])
        @path = Pathname.new(path).realpath.to_s.freeze
        @closed = false
        @sections = Set.new(sections)
      end

      def finalize!
        @closed = true
        @sections.freeze
      end

      # initialize and add a new library section
      def section(media_subclass)
        @sections.add media_subclass
      end

      # True if the given path is in this root
      def in_root?(path)
        fp = Pathname.new(path).realpath.to_s
        fp.start_with? path
      end

      # TODO replace with an exception type
      def path_not_under_error(other_path)
        raise PathError, "Path #{other_path} not under root #{self.to_s}"
      end

      # Returns path as relative to this root
      def relative_path(full_path)
        full_path = Pathname.new(full_path).realpath.to_s
        if in_root? full_path
          # sliced to size of relative path
          return full_path[path.length..-1]
        end

        path_not_under_error full_path
      end

      # import a file into the library. basic algorithm:
      #   1. is this path within the Root?
      #   2. for each @sections:
      #     - does this path go in this section?
      #     - does this path have the right extension?
      #     - is this path already in the database?
      #     - cool, import using section.new section.regex.match(relative_path)
      # TODO: log all import operations
      def index_file(full_path)
        # only files that exist
        fp = Pathname.new(full_path).realpath

        # only files
        return false unless fp.file?

        # fp must be in root
        unless in_root? fp
          path_not_under_error fp
        end

        rp = fp.to_s[path.length..-1]

        @sections.each do |s|
          if s.prefix =~ rp and s.suffix =~ rp
            return s.index_path(rp)
          end
        end

        # abject failure
        false
      end

      # import all the files first before recursing into directories
      # breadth-first
      def index_directory(full_path)
        fp = Pathname.new(full_path).realpath

        # only directories
        return false unless fp.directory?

        # only directories in the root
        unless in_root? fp
          path_not_under_error fp
        end

        # breadth-first
        index_entries = []
        dirs = []

        fp.each_child do |child|
          if child.directory?
            dirs << child
            next
          end

          entry = self.index_file(child)
          index_entries << entry if entry
        end

        # now import directories
        dirs.each do |dir|
          index_entries = index_entries | index_directory(dir)
        end

        index_entries
      end

      # remove a path from the index
      def remove(full_path)
        full_path = Pathname.new(full_path).realpath.to_s
        unless in_root? full_path
          path_not_under_error full_path
        end

        # find which type of model this is
        rp = relative_path(full_path)

        repr = Media.first(:relative_path => rp)
        repr.delete!
      end
    end

  end
end
require 'data_mapper'
require 'active_support/core_ext/class/attribute'
require 'pathname'

module Teevee
  module Library

    # A single library containing lots of media
    # all media paths are stored relative to a root, so that multiple
    # systems mounting the same share to various mount points can look at a thing
    # and all agree that everything is in the same place
    class Root

      # root path
      attr_reader :path

      def initialize(path)
        @path = Pathname.new(path).realpath.to_s.freeze
        @closed = false
        @sections = Set.new
      end

      def finalize!
        @closed = true
        @sections.freeze
      end

      # initialize and add a new library section
      def section(media_subclass)
        @sections.add media_subclass
        media_subclass.library = self
      end

      # import a file into the library. basic algorithm:
      #   1. is this path within the Root?
      #   2. for each @sections:
      #     - does this path go in this section?
      #     - does this path have the right extension?
      #     - is this path already in the database?
      #     - cool, import using section.new section.regex.match(relative_path)
      # TODO: log all import operations
      def import_file(full_path)
        # only files that exist
        fp = Pathname.new(full_path).realpath

        # only files
        return false unless fp.file?

        # fp must be in root
        fp = fp.to_s
        return false unless fp.starts_with? path

        rp = fp[path.length..-1]

        @sections.each do |s|
          if s.prefix =~ rp and s.suffix =~ rp
            return s.import_relative(rp)
          end
        end

        # abject failure
        return false
      end

      # import all the files first before recursing into directories
      # breadth-first
      def import_directory(full_path)
        fp = Pathname.new(full_path).realpath

        # only directories
        return false unless fp.directory?

        # breadth-first
        dirs = []

        fp.each_child do |child|
          if child.directory?
            dirs << child
            next
          end

          self.import_file(child)
        end

        # now import directories
        dirs.each do |dir|
          import_directory(dir)
        end
      end

    end

    # Database storage classes
    class Media

      # suffixes are replaced by this value before the regex is run
      # you should use #{SUFIX} in your REGEX to denote the end.
      SUFFIX = '__SUFFIX__'.freeze

      # The {Library} that contains this Section
      class_attribute :library

      # Regex with named sections to select the data for each field
      # from the truncated path of a given record
      class_attribute :regex

      # Prefix regexp (starts with ^) to detect that this library section
      # should be used
      class_attribute :prefix

      # Suffix regex to detect the correct filetypes for import into this section
      class_attribute :suffix

      # Suffix regext (ends with $) to detect the correct extensions for this
      # filetype. Run after prefix filtering
      class_attribute :suffix

      # import the file at `rp` under self.root as a new Media of this type
      def self.import_relative(rp)
        # trip prefix and suffix
        rp = rp.gsub(self.prefix, '')
        rp = rp.gsub(self.suffix, SUFFIX)

        matches = self.regex.match(rp)
        self.new(matches.to_hash)
      end

      ### DataMapper Properties
      include DataMapper::Resource
      property :id,             Serial
      property :relative_path,  String # path from root
    end

    class Movie < Media
      # like /Movies/Zoolander (2001).avi
      property :title,          String
      property :year,           Integer
      self.regex = %r{
        (?<title> .*?)       # title is lots of character
        \s\(                 # exclude a space and open year
        (?<year> \d+)        # match year
        \)#{SUFFIX}$         # close parens then suffix
      }x
    end

    class Song < Media
      # like /Music/Röyksopp/Junior/[10] Röyksopp - True to Life.mp3
      property :title,          String
      property :artist,         String
      property :album,          String
      property :track_num,      Integer
      property :grouping,       String  # for non-album tracks
    end

    class Episode < Media
      # like /Television/Game of Thrones/Season 02/Game of Thrones - S02E03 - What is Dead May Never Die.mp4
      property :show,           String
      property :season,         Integer
      property :episode_num,    Integer
      property :grouping,       String # for episodes without seasons
      property :title,          String # for named episodes (most)
    end

  end
end
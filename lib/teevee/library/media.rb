# -*- encoding : utf-8 -*-
require 'data_mapper'
require 'active_support/core_ext/class/attribute'
require 'pathname'

require 'teevee/searchable'

# Use 255-char long strings by default
DataMapper::Property::String.length(0..255)

module Teevee
  module Library

    # Times with fractional seconds screw up my Postgres queries
    # this supplies us with a source of DateTime objects unclouded by fractional seconds
    def self.rough_time(time = nil)
      time = DateTime.now if time.nil?

      time = time.to_time if time.is_a? DateTime
      Time.at(time.to_i).to_datetime
    end

    # Database storage class
    # we're using a database so we can take advantage of Postgres's built-in
    # full-text search. A fuzzy-matching search was considered but discarded
    # because voice input is unlikely to have substring matches
    class Media

      ### DataMapper Properties ###############################################
      include DataMapper::Resource
      property :id,             Serial

      # path of the media resource from the library root
      property :relative_path,  String, :unique_index => true,
                                        :required => true

      # used for pruning old things from the index:
      # 1. started = Time.now
      # 2. scan each file, updating its :last_seen to Time.now
      # 3. DELETE FROM media WHERE last_seen < started
      property :last_seen,      DateTime, :default => proc {Library.rough_time}



      ### Full Text Search ####################################################
      include Teevee::Searchable
      self.search_indexes =  [:relative_path]



      ### Teevee Indexing #####################################################

      # suffixes are replaced by this value before the regex is run
      # you should use #{SUFIX} in your REGEX to denote the end.
      SUFFIX = '__SUFFIX__'.freeze

      # Regex with named sections to select the data for each field
      # from the truncated path of a given record
      class_attribute :regex

      # Suffix regext (ends with $) to detect the correct extensions for this
      # filetype. Run after prefix filtering
      class_attribute :suffix


      # Convert a MatchData object to a plain ruby hash
      # for use with named captures in a regex
      def self.match_to_hash(match)
        res = {}
        match.names.each {|name| res[name.to_sym] = match[name]}
        res
      end

      def self.should_contain?(relative_path)
        (self.suffix =~ relative_path) and (self.prefix =~ relative_path)
      end

      def self.stripped_path(relative_path, prefix)
        stripped = relative_path.gsub(%r{^#{prefix}/}, '')
        stripped.gsub(self.suffix, SUFFIX)
      end

      def self.data_from_path(rp, prefix)
        stripped = stripped_path(rp, prefix)

        # TODO handle a no-match case
        match = self.regex.match(stripped)
        if match
          data = match_to_hash(match)
          data[:relative_path] = rp.to_s
          return data
        end
        return nil
      end

      # import the file at `relative_path` under self.root as a new Media of
      # this type
      def self.index_path(rp, prefix)
        data = data_from_path(rp, prefix)
        return nil if data.nil?

        # type coerce the data because DataMapper doesn't seem to do it for us
        # i am having untold struggles with Indexer#scan because it won't save episdoes
        # where ep.season = '04' instead of 4
        int_props = self.properties.select{|p| p.is_a? DataMapper::Property::Integer}.map{|p| p.name}
        int_props.delete(:id) # no need to cast ID
        int_props.each do |name|
          data[name] = data[name].to_i if data.include? name
        end

        return self.new(data) if data
        return nil
      end

      # Returns the friendly name of a media file, for displaying in a UI
      # @return [String] friendly name
      def friendly_name
        Pathname.new(self.relative_path).basename.to_s
      end


      ### default matchers
      self.suffix = /\.\w{3,}$/
      self.regex  = //
    end

    # A movie file in the library
    class Movie < Media
      # like /Movies/Zoolander (2001).avi
      property :title,          String
      property :year,           Integer
      self.search_indexes = [:title]
      self.suffix = %r{\.(mkv|m4v|mov|avi|flv|mpg|wmv|mp4)$}
      self.regex = %r{
        (?:                  # <title> (<year>) or <title>
          (?:
            (?<title> [^/]+)     # title is lots of character
            \s\(                 # (
            (?<year> \d+)        # <year>
            \)                   # )
          )
          |                    # OR
          (?<title> [^/]+)
        )
        #{SUFFIX}$         # close parens then suffix
      }x
    end

    # a single song
    # we might not use this thing, because songs are haaaard to index
    class Track < Media
      # like /Music/Röyksopp/Junior/[10] Röyksopp - True to Life.mp3
      property :title,          String
      property :artist,         String
      property :album,          String
      property :track_num,      Integer
      property :grouping,       String  # for non-album tracks
      self.search_indexes = [:title, :artist, :album, :grouping]
    end

    # an episode of a TV show or anime
    class Episode < Media
      # like /Television/Game of Thrones/Season 02/Game of Thrones - S02E03 - What is Dead May Never Die.mp4
      property :show,           String
      property :season,         Integer # note that these two fields MUST be its to #save the model
      property :episode_num,    Integer
      property :grouping,       String # for episodes without seasons
      property :title,          String # for named episodes (most)
      self.search_indexes = [:show, :grouping, :title]
      self.suffix = Movie.suffix
      self.regex = %r{
      ^                           # BEGIN
      (?<show> [^/]+)/            # <Show>/
      (?:                         # Season or Grouping?
        Season\s(?<season>\d+)      # Season <XX>
        |
        (?<grouping>[^/]+)          # <grouping>
      )/
      (?:                         # Episode info or garbage
        (?:                         # regular episode format: <Series> - SXXE<XX> - <title>.m4v
          [^/]+?                      # show again
          \s-\s                       # -
          (?:                         # SXXE<XX> or garbage
            S\d+                        # SXX
            E(?<episode_num>\d+)        # E<XX>
            |                           # OR
            [^/]+?                      # some garbage
          )
          \s-\s                       # -
          (?<title>.+?)               # <title>
        )
        |                           # OR
        (?<title> [^/]+)            # just a title
      )
      #{SUFFIX}                   # suffix
      $                           # END
      }x
    end


    Sections = {
        "Movies" => Movie,
        "Music" => Track,
        "Television" => Episode
    }

  end
end

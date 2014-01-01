require 'data_mapper'
require 'active_support/core_ext/class/attribute'

module Teevee
  module Library

    # Database storage class
    # we're using a database so we can take advantage of Postgres's built-in
    # full-text search. A fuzzy-matching search was considered but discarded
    # because voice input is unlikely to have substring matches
    class Media

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
        Hash[ match.names.zip( match.captures ) ]
      end

      def self.should_contain?(relative_path)
        (self.suffix =~ relative_path) and (self.prefix =~ relative_path)
      end

      def self.stripped_path(relative_path, prefix)
        stripped = relative_path.gsub(%r{^#{prefix}/}, '')
        stripped.gsub(self.suffix, SUFFIX)
      end

      # import the file at `relative_path` under self.root as a new Media of
      # this type
      def self.index_path(rp, prefix)
        stripped = stripped_path(rp, prefix)

        # TODO handle a no-match case
        data = match_to_hash self.regex.match(stripped)
        data[:relative_path] = rp
        self.new(data)
      end

      ### default matchers
      self.suffix = /\.\w{3,}$/
      self.regex  = //

      ### DataMapper Properties
      include DataMapper::Resource
      property :id,             Serial

      # path of the media resource from the library root
      property :relative_path,  String, :unique => true,
                                        :required => true
    end

    # A movie file in the library
    class Movie < Media
      # like /Movies/Zoolander (2001).avi
      property :title,          String
      property :year,           Integer
      self.suffix = %r{\.(mkv|m4v|mov|avi|flv|mpg|wmv)$}
      self.regex = %r{
        (?<title> .*?)       # title is lots of character
        \s\(                 # exclude a space and open year
        (?<year> \d+)        # match year
        \)#{SUFFIX}$         # close parens then suffix
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
    end

    # an episode of a TV show or anime
    class Episode < Media
      # like /Television/Game of Thrones/Season 02/Game of Thrones - S02E03 - What is Dead May Never Die.mp4
      property :show,           String
      property :season,         Integer
      property :episode_num,    Integer
      property :grouping,       String # for episodes without seasons
      property :title,          String # for named episodes (most)
      self.suffix = Movie.suffix
      self.regex = %r{
      (?<show> [^/+]) /                # Show/
      (?:(?:                           # Season XX/ or <anything>/ , optional
        (?:Season\s(?<season> \d+)) |     # Season XX
        (?<grouping> [^/+])               # <anything>
      )/)?
      (?:                               # <Show> - SXXEXX - <Title>, or, <anything>
        (?:                               # well-formatted name
          \k<show>                          # show name repeated
          \s-\s                             # -
          S\d+                              # SXX
          E(?<episode_num>\d+)              # EXX
          \s-\s                             # -
          (?:<title>.+?)                    # <title>
        ) |                               # OR
        (?:<title>.+?)                    # anything
      )
      #{SUFFIX}$                        # suffix
      }x
    end


    Sections = {
        "Movies" => Movie,
        "Music" => Track,
        "Television" => Episode
    }

  end
end
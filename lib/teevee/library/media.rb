# -*- encoding : utf-8 -*-
require 'pathname'
require 'active_support/core_ext/class/attribute'
require 'teevee/searchable'

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
    class Media < Sequel::Model(:media)

      plugin :single_table_inheritance, :type
      plugin :after_initialize

      # auto-timestamp on creation
      def after_initialize
        super
        self.last_seen ||= Teevee::Library.rough_time
      end

      ### Full Text Search ####################################################
      plugin Teevee::Searchable

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

        # much ado about coercion removed because Sequel does it for us.

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

      # attr_accessor :title,
      #               :year

      # like /Movies/Zoolander (2001).avi
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

    # an episode of a TV show or anime
    class Episode < Media

      # like /Television/Game of Thrones/Season 02/Game of Thrones - S02E03 - What is Dead May Never Die.mp4
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

  end
end

# My initial idea for this file was to have two classes, Library and LibrarySection
# work together to describe an arbitrary library setup. Here's the idealized
# code sample for creating a new Library instance:
lib = Teevee::Library.new('/Volumes/Media') do |lib|
  lib.section "movies" do |s|
    s.prefix = /^Movies/
    s.fields :title, :year
    s.regex = /some regex with named groups "title" and "year"/
  end

  lib.section "books" do |s|
    s.prefix = /^Books/
    s.fields :title
    # regex too
  end

  lib.section "tv" do |s|
    s.prefix = /^Television/
    s.fields :season, :episode, :title, :grouping # grouping for non-seasons
    # regex too
  end

  lib.section "music" do |s|
    s.prefix = /^Music/
    s.fields :title, :artist, :album, :track_num, :grouping # grouping for non-albums
    # regex too
  end

  # generates lib.Record, an ActiveRecord store with all the fields required
  # by all the sections
  lib.finalize!
end

# then we use lib.add(path) to generate insert a new object in the index
# and lib.listen! to start listening for FS changes with the Listen gem.
# but I'm not sure how ActiveRecord will handle that design.

require 'listen'
require 'set'

require 'active_record'

module Teevee

  # a directory full of media for us to watch
  class Library

    def initialize(path)
      @path = path
      @closed = false
      @sections = Set.new
    end

    def finalize!
      @closed = true
      @sections.freeze
    end

    # initialize and add a new library section
    def section(name, &block)
      @sections.add LibrarySection.new(name, &block)
    end


  end

  # stores the path-data-extraction rules for one area of a media library
  # say, the Music library, the Movies library, etc are all
  class LibrarySection
    # The {Library} that contains this Section
    attr_accessor :library

    # Prefix regexp (starts with ^) to detect that this library section
    # should be used
    attr_accessor :prefix

    # creates a new section
    # should be run from inside a library with Library#section
    def initialize(name)
      @name = name.to_sym
      @fields = Set.new

      yield self if block_given?
    end

    # define what fields this library should have
    # each field will need a match in the #path_regex field
    def fields(*field_names)
      field_names.each do |name|
        @fields.add name.to_sym
      end
    end

  end

end
# -*- encoding : utf-8 -*-
module Teevee

  # Manages indexing a library of media. Use {Root} to create a new
  # logical library root, and populate it with sections. Each
  # section is a subclass of Library::Media, with defined regexes
  # Section.prefix, Section.suffix, and Section.regex
  #
  # TODO: fixtures for scanning the libray for changes, and garbage
  # collecting the database
  module Library
  end

end

require 'teevee/library/root'
require 'teevee/library/media'
require 'teevee/library/indexer'

# -*- encoding : utf-8 -*-
module Teevee

  # The daemon module uses the rest of the Teevee library to generate and respond
  # to media requests, update a library, etc.
  # it should eventually be totally configurable from a single DSL config file
  class Application
    attr_reader :root, :indexer, :vlc, :options, :plugins, :wit_token

    def initialize(root, indexer, wit_token, opts)
      @root = root
      @indexer = indexer
      @options = opts
      @wit_token = wit_token
      @plugins = Teevee::Plugin::List.new
    end
  end # end Application


end

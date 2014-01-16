# -*- encoding : utf-8 -*-
module Teevee

  # The daemon module uses the rest of the Teevee library to generate and respond
  # to media requests, update a library, etc.
  # it should eventually be totally configurable from a single DSL config file

  class Application
    attr_reader :root, :indexer, :vlc, :options, :plugins

    def initialize(root, indexer, opts)
      @root = root
      @indexer = indexer
      @vlc = VLC::System.new('127.0.0.1', 9999, auto_start: false)
      @options = opts
      @plugins = Teevee::Plugin::List.new
    end
  end # end Application


end

require 'teevee/daemon/cli'
require 'teevee/daemon/web_remote'
require 'teevee/daemon/runtime'

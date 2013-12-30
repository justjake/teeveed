#!/usr/bin/env ruby
# teeveed - your media center daemon
# https://github.com/justjake/teeveed
# GNU GPLv3

require 'rubygems'
require 'bundler'
Bundler.setup

# web dependencies
require 'sinatra/base'
require 'haml'
require 'JSON'

# CLU dependencies
require 'pry-remote'

# our software
require 'teevee'

WIT_ACCESS_TOKEN = ENV['WIT_ACCESS_TOKEN']
TEEVEED_HOME = Pathname.new(__FILE__).parent.parent.realpath + 'arena'

# in-memory DB for now
DataMapper.setup(:default, 'sqlite::memory:')
DataMapper.finalize
DataMapper.auto_migrate!

# the daemon itself
module Teeveed

  # the WebRemote is a simple webapp that dispatches actions based
  # on user input from a webform. it is intended to be used via dictation
  # from a mobile device.
  class Remote < Sinatra::Base
    ### SETTINGS
    set :bind, '0.0.0.0'
    set :port, 1337

    ### TEMPLATES
    # default template
    HOMEPAGE = %(
  !!! 5
  %html
    %head
      %title teeveed
      %meta(name="viewport" content="width=device-width")
    %body
      %form(action="" method="post")
        %h2 Ask
        %textarea(name="q" style="width: 100%;")
        %input(type="submit" name="send")
  )

    # template showing a response, too
    RESP = HOMEPAGE + %(
      %div
        %h2 Receive
        %pre
          %code
            = @intent_json
  )
    template :index do
      HOMEPAGE
    end

    template :response do
      RESP
    end

    ### HTTP HANDLERS

    get '/' do
      haml HOMEPAGE
    end

    post '/' do
      wit = Teevee::Wit.new
      @intent = wit.message(params[:q])
      @intent_json = JSON.pretty_generate(@intent)

      # TODO: dispatch on @intent

      haml RESP
    end
  end

  class CLI
    # easy access
    include Teevee

    attr_reader :root, :wit
    attr_accessor :store

    def initialize
      @wit = Wit.new
      @root = Library::Root.new(TEEVEED_HOME + 'library', Library::Sections)
    end

    def data
      'library/Movies/The Incredibles (2008).mkv'
    end

    def say(msg)
      @wit.message(msg)
    end

    def index(path)
      @root.index_file(path)
    end

    def interact!
      binding.pry_remote
    end
  end

end

# start the webserver for the remote in a thread
cli = Teeveed::CLI.new
path_to_index = TEEVEED_HOME + cli.data
row = cli.index(path_to_index)
p "indexed #{path_to_index} "
cli.store = row


web = Thread.new do
  Teeveed::Remote.run!
end

# start pry-remote in new thread
debug = Thread.new do
  while true do
    cli.interact!
  end
end

# wait forever pretty much
[web, debug].each {|t| t.join}

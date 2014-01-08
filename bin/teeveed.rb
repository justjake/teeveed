#!/usr/bin/env ruby
# teeveed - your media center daemon
# https://github.com/justjake/teeveed
# GNU GPLv3

# first do options things
require 'trollop'
opts = Trollop::options do
  # opt :indexer, "Launch indexer. currently unimplemented"
  opt :cli, "boot into a local pry session"
  opt :remote, "Launch remote pry debug server"

  opt :web, "Launch webserver", default: true
  opt :ip, "listening ip for the web ui", :default => '0.0.0.0'
  opt :port, "listening port for the web ui", :default => '1337'

  opt :migrate, "Destroy and re-create the database"
  opt :down, "migrate down - undo migration #X", :type => :ints
  opt :up, "migrate up - perform migrations #X", :type => :ints
  opt :trash, "trash any exisiting migration state data"

  opt :wit_token, "wit oauth2 access token.", :type => :string

  opt :config, "config file to load", :default => "#{ENV['HOME']}/.teeveed.conf.rb"
end
# default to empty arrays
[:up, :down].each{|name| opts[name] ||= []}
# read WIT_ACCESS_TOKEN from ENV
opts[:wit_token] ||= ENV['WIT_ACCESS_TOKEN']

require 'rubygems'
require 'bundler'
Bundler.setup

# our software
require 'teevee'
require 'teevee/daemon'

# engage tricky business
Teevee::Daemon::Runner.initial_options(opts)
include Teevee::Daemon::Runner

# load user config
begin
  load config_path
rescue LoadError => e
  Trollop::die :config, "load error: #{e.message}"
end

# WOO HOO
boot!

#!/usr/bin/env ruby
# teeveed - your media center daemon
# https://github.com/justjake/teeveed
# GNU GPLv3

# first do options things
require 'trollop'
opts = Trollop::options do
  # opt :indexer, "Launch indexer. currently unimplemented"
  opt :cli, 'boot into a local pry session'
  opt :remote, 'Launch remote pry debug server'

  opt :web, 'Launch webserver'
  opt :ip, 'listening ip for the web ui'
  opt :port, 'listening port for the web ui'

  opt :migrate, 'Destroy and re-create the database'
  opt :down, 'migrate down - undo migration #X', :type => :ints
  opt :up, 'migrate up - perform migrations #X', :type => :ints
  opt :force, 'force migrate. destroys whole database'

  opt :wit_token, 'wit oauth2 access token. Can also be provided via $WIT_ACCESS_TOKEN', :type => :string

  opt :config, 'config file to load', :default => "#{ENV['HOME']}/.teeveed.conf.rb"
  opt :scan, 'scan library at boot'
  opt :verbosity, 'set the log level', :type => :int, :default => 3
end
# default to empty arrays
[:up, :down].each{|name| opts[name] ||= []}
# read WIT_ACCESS_TOKEN from ENV
opts[:wit_token] ||= ENV['WIT_ACCESS_TOKEN']

# our software
require 'teevee'
require 'teevee/daemon'

# prepare logging
Teevee.log_level = opts[:verbosity]

# engage tricky business
include Teevee::Daemon::Runtime
initial_options(opts)

# load user config
begin
  Teevee.log(5, 'boot', 'loading user config...')
  load opts[:config]
rescue LoadError => e
  Trollop::die :config, "load error: #{e.message}"
end

# WOO HOO
boot!

#!/usr/bin/env ruby
# -*- encoding : utf-8 -*-

# teeveed - your media center daemon
# https://github.com/justjake/teeveed
# GNU GPLv3

# first do options things
require 'trollop'
opts = Trollop::options do
  opt :cli, 'boot into a local pry session'
  opt :remote, 'Launch remote pry debug server'

  opt :web, 'Launch webserver'
  opt :ip, 'listening ip for the web ui'
  opt :port, 'listening port for the web ui'

  opt :hud, 'enable on-screen user interface'

  opt :migrate, 'apply migrations folder, from --from to --to', :type => :string
  opt :from, 'migrate starting here', :type => :int
  opt :to, 'migrate to here', :type => :int

  opt :wit_token, 'wit oauth2 access token. Can also be provided via $WIT_ACCESS_TOKEN', :type => :string

  opt :config, 'config file to load', :default => "#{ENV['HOME']}/.teeveed.conf.rb"
  opt :scan, 'scan library at boot'
  opt :verbosity, 'set the log level', :type => :int, :default => 3
end

# read WIT_ACCESS_TOKEN from ENV if it wasn't an argument
opts[:wit_token] ||= ENV['WIT_ACCESS_TOKEN']

# Migrations require a --from and a --to
if (opts[:migrate] || opts[:from] || opts[:to]) and not (opts[:migrate] and opts[:to])
  Trollop::die :migrate, '--migrate requires --to, and --from requires both'
end

# migrations require a real folder with files in it
if opts[:migrate]
  require 'pathname'
  begin
    was_dir = Pathname.new(opts[:migrate]).realpath.directory?
    Trollop::die :migrate, "#{opts[:migrate]} isn't a directory" unless was_dir
  rescue ArgumentError => e
    Trollop::die :migrate, "#{opts[:migrate]} isn't a directory"
  end
end

# our software
# TODO - require each file manually
require 'teevee'
require 'teevee/library/root'
require 'teevee/library/indexer'
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

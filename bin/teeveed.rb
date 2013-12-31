#!/usr/bin/env ruby
# teeveed - your media center daemon
# https://github.com/justjake/teeveed
# GNU GPLv3

# config
WIT_ACCESS_TOKEN = ENV['WIT_ACCESS_TOKEN']
TEEVEED_HOME = Pathname.new(__FILE__).parent.parent.realpath + 'arena'
REMOTE_IP = '0.0.0.0'
REMOTE_PORT = 1337

require 'rubygems'
require 'bundler'
Bundler.setup

# our software
require 'teevee'
require 'teevee/daemon'


### Set up database
# in-memory DB for now
DataMapper.setup(:default, 'sqlite::memory:')
DataMapper.finalize
DataMapper.auto_migrate!

### some siple tests
cli = Teevee::Daemon::CLI.new
path_to_index = TEEVEED_HOME + cli.data
row = cli.index(path_to_index)
p "indexed #{path_to_index} "
cli.store = row


# start the webserver for the remote in a thread
web = Thread.new do
  Teevee::Daemon::Remote.run!
end

# start pry-remote in a thread
debug = Thread.new do
  while true do
    cli.interact!
  end
end

# wait for our server (forever)
[web, debug].each {|t| t.join}

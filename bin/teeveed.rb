#!/usr/bin/env ruby
# teeveed - your media center daemon
# https://github.com/justjake/teeveed
# GNU GPLv3

# try to run in cmd.exe
if ARGV[0] == 'launch'
  `start "Teeveed Console" /max cmd.exe /k jruby '#{__FILE__}' cli`
  puts "finished CLI session"
  exit 0
end

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

TEST_PATHS = [
    'Television/Game of Thrones/Season 02/Game of Thrones - S02E03 - What is Dead May Never Die.mp4',
    'Movies/Zoolander (2001).avi'
]

### some siple tests
root = Teevee::Library::Root.new (TEEVEED_HOME+'library').to_s, {
    'Television' => Teevee::Library::Episode,
    'Movies' => Teevee::Library::Movie
}
cli = Teevee::Daemon::CLI.new

TEST_PATHS.each do |path|
  path = cli.root.pathname + path
  begin
    row = root.index_path(path)
    if row
      puts "SUCCESS: indexed #{path} as \n#{row.inspect}"
      cli.store = row
    else
      puts "FAILURE: couldn't index #{path}"
    end
  rescue => err
    puts "FAILURE: exeption #{err}"
    puts err.backtrace
  end
end

if ARGV[0] == 'cli'
  binding.pry
end

### daemonize if env is right
if ENV['TEEVEED_DAEMONIZE'] == 'YES'
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
end

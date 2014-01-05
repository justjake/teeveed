#!/usr/bin/env ruby
# teeveed - your media center daemon
# https://github.com/justjake/teeveed
# GNU GPLv3

# first do options things
require 'trollop'
opts = Trollop::options do
  opt :indexer, "Launch indexer. currently unimplemented"
  opt :cli, "boot into a local pry session"
  opt :remote, "Launch remote pry debug server", default: true
  opt :wit_token, "wit oauth2 access token.", :type => :string

  opt :web, "Launch webserver", default: true
  opt :ip, "listening ip for the web ui", :default => '0.0.0.0'
  opt :port, "listening port for the web ui", :default => '1337'
end

# config
WIT_ACCESS_TOKEN = opts[:wit_token] || ENV['WIT_ACCESS_TOKEN']
TEEVEED_HOME = Pathname.new(__FILE__).parent.parent.realpath + 'arena'
REMOTE_IP = opts[:ip]
REMOTE_PORT = opts[:port]

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
root = Teevee::Library::Root.new (TEEVEED_HOME+'library').to_s, {
    'Television' => Teevee::Library::Episode,
    'Movies' => Teevee::Library::Movie
}
## test importing of the whole shebang
imported = root.index_recusive(root.path)
imported.each do |repr|
  puts "Imported #{repr.relative_path}:\n\t#{repr.inspect}"
end


if opts[:cli]
  api = Teevee::Wit::API.new(WIT_ACCESS_TOKEN)
  binding.pry
  exit 0
end

### daemonize if env is right
threads = []

if opts[:web]
  # start the webserver for the remote in a thread
  web = Thread.new do
    Teevee::Daemon::Remote.run!
  end
  threads << web
end

if opts[:remote]
  # start pry-remote in a thread
  debug = Thread.new do
    while true do
      cli.interact!
    end
  end
  threads << debug
end

# wait for our server (forever)
threads.each {|t| t.join}

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
end
# default to empty arrays
[:up, :down].each{|name| opts[name] ||= []}
# if :opts[:migrate] and (opts[:down].nil? && opts[:up].nil?)
#   Trollop::die "derp", "Migrate requires --up or --down"
# end

# config
require 'pathname'
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
DataMapper.setup(:default, 'postgres://teeveed:teeveed@localhost/teeveed')
DataMapper.finalize

# perform migrations and exit
if opts[:migrate]
  DataMapper::Logger.new(STDOUT, :debug)
  DataMapper.logger.debug( "Starting migrations, up: #{opts[:up]}, down: #{opts[:down]}" )

  # we aren't using transactions in the migrations, so.... do this instead when things
  # blow up and state gets messy :(
  # TODO switch migrations to transactions
  if opts[:trash]
    adapter = DataMapper.repository(@repository).adapter
    adapter.execute('DROP TABLE migration_info;')
  end

  migrations = Teevee::Migrations::generate(Teevee::Library::Media)
  ups = migrations.select{|m| opts[:up].include? m.position }
  downs = migrations.select{|m| opts[:down].include? m.position }

  downs.reverse.each {|m| m.perform_down}
  ups.each {|m| m.perform_up}

  exit 0
end

### some simple tests
root = Teevee::Library::Root.new (TEEVEED_HOME+'library').to_s, {
    'Television' => Teevee::Library::Episode,
    'Movies' => Teevee::Library::Movie
}
# # test importing of the whole shebang
# imported = root.index_recusive(root.path)
# imported.each do |repr|
#   puts "Imported #{repr.relative_path}:\n\t#{repr.inspect}"
# end


if opts[:cli]
  api = Teevee::Wit::API.new(WIT_ACCESS_TOKEN)
  indexer = Teevee::Library::Indexer.new(root)
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

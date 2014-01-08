# test config file
database 'postgres://teeveed:teeveed@localhost/teeveed'

path = (Pathname.new(__FILE__).parent.parent+'arena/library').to_s

enable_webui
enable_remote_debugging

library path do
  section 'Television' => Episode
  section 'Movies' => Movie
end

schedule :every, 1.minutes do
  puts "ever minute!"
  scan_for_changes 'Movies'
end

schedule :every, 4.minutes do
  puts "every 4 minutes!"
  scan_for_changes 'Television'
end

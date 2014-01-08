# test config file
database 'postgres://teeveed:teeveed@localhost/teeveed'

path = (Pathname.new(__FILE__).parent.parent+'arena/library').to_s

library path do
  section 'Television' => Episode
  section 'Movies' => Movie
end

webui ip: '0.0.0.0', port: 1337
# enable_remote_debugging
scan_at_startup
log_level 4  # show prunings but not most scan bullshit at lvl 5

schedule :every, 1.minutes do
  log 2, 'scanning Movies (every minute)'
  scan_for_changes 'Movies'
end

schedule :every, 4.minutes do
  log 2, 'scanning Television (every 4 minutes)'
  scan_for_changes 'Television'
end

# -*- encoding : utf-8 -*-
# Teeveed
# Example config file.
# place at ~/.teeveed.conf.rb

# required. URI of a postgres database
database 'postgres://teeveed:teeveed@localhost/teeveed'

# required. Filesystem location of your media library
library '/Volumes/Media' do
  # section DIR => MEDIA TYPE, where MEDIA TYPE is Episode or Movie
  # Teeveed will look in DIR for media
  section 'Television' => Episode
  section 'Movies' => Movie
end

# operate the web ui on internet address 0.0.0.0:1337
webui ip: '0.0.0.0', port: 1337

### Unused config functions:
# enable_remote_debugging - turns on Ruby remote debugging. Highly insecure.
# wit_token STRING        - specify your Wit.ai token in the config file
# rebuild_index           - destroy and recreate the whole index. Use from
#                           a scheduled action
###

# scan the library when booting Teeveed
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

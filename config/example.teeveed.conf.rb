# -*- encoding : utf-8 -*-
# Teeveed
# Example config file.
# place at ~/.teeveed.conf.rb

### Core Settings ###################################################
# database -- required. URI of a postgres database
database 'jdbc:postgresql://localhost/teeveed?user=teeveed&password=teeveed'

# library -- required. Filesystem location of your media library
library '/Volumes/Media' do
  # section DIR => MEDIA TYPE, where MEDIA TYPE is :Episode or :Movie
  # Teeveed will look in DIR for media
  section 'Television' => :Episode
  section 'Movies' => :Movie
end

log_level 4  # show prunings but not most scan bullshit at lvl 5

# wit_token -- teeveed needs a Wit.ai instance key to process commands,
#             but not to index.
wit_token 'YOUR API KEY HERE'




### Plugins #########################################################
# All of teeveed's  functionality is loaded via plugins.
# the included plugins are
# :web_ui -- the main interface. use this to issue commands to teeveed
plugin :web_ui, ip: '0.0.0.0', port: 1337

# :play_videos_with_vlc -- intents for playing back Movies and Episodes with VLC
plugin :play_videos_with_vlc

# :remote_debugger -- a pry-remote based debugger. connect with the pry-remote gem
# plugin :remote_debugger

# :heads_up_display -- an on-screen display for your TV. requires JavaFX in your $JRE_HOME/lib/ext
plugin :heads_up_display




### Scheduled actions ###############################################
# un-demonstrated actions:
# rebuild_index           - destroy and recreate the whole index. Use from
#                           a scheduled action. Dangerous on large indexes.
###

schedule :every, 1.minutes do
  log 2, 'scanning Movies (every minute)'
  scan_for_changes 'Movies'
end

schedule :every, 4.minutes do
  log 2, 'scanning Television (every 4 minutes)'
  scan_for_changes 'Television'
end

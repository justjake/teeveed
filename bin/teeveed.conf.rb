# example teeveed.conf
# dsl not yet implemented, stretch goal
# this file would be `load`ed from the teeveed binary during launch, from
# ~/.teeveed/conf.rb, or from `java -jar teeveed.jar --conf PATH`

database 'psql://localhost:4532',
         username: 'teeveed',
         password: 'a892304ynvhafo98awnugn980e5t437vtoqckhsa'

# define a library for teeveed to index and show movies from
# nickname is not required. Here are the different signatures
# library(Hash<Symbol, Any> opts, &block)
#   path: required. defines the root directory of the library. must exist.
#   nickname: Optional. shortname for the library for referencing in `schedule`
#     and other config blocks.
#  library(String path, &block)
#     library nickanme = path
# libraries must be defined before scheduling can happen for them.
library nickname: 'Media', path: '/mnt/storage' do |lib|
  lib.section 'Television/' do |sect|
    sect.type = Episode
  end
  lib.section 'Movies/' do |sect|
    sect.type = Movie
  end
  lib.section 'Music/' do |sect|
    sect.type = Song
    sect.no_index!
  end
end

# or schedule control could be somewhere else
schedule do
  # it may be tricking figuring out how to translate ever(30.seconds) into some
  # sort of parameter for a library.indexer
  # TODO: think about what sort of problems allowing this would pose
  every(30.seconds) do
    # if you have multiple libraries, the library name is required
    # unnamed libraries can be referred to by the path
    scan_for_changes 'Media', 'Television/'
  end

  every(10.seconds) do
    scan_for_changes('Movies/')
  end

  daily(3.am) do
    rebuild_index('/Television')
  end
end

# or use cron to schedule these things seperatley, which is the unix way
# + unix tooling exists
# + neckbeard cred
# + more scriptable to change, do dynamic behaviors
# - JVM startup times on "every 30 seconds" things are loooooong
# - cron and friends is tricky/different on OS X?
# - cron on windows?!?!?? get real. if you're doing Jar stuff,
#   then people expect it to do more of the lifing. Even more so if we do public
#   downloads in the distant future

# front-end systems
ui do
  fullscreen
  size 1920, 1080
  color 0x000000
end
# headless systems
ui do
  disable!
end

# web remote
remote do
  ip '0.0.0.0'
  port 8080
end

# index-only systems
remote do
  disable!
end

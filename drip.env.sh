# Source this file if you use Drip to make the JVM not suck
# drip: https://github.com/flatland/drip
# https://github.com/flatland/drip/wiki/JRuby

# JAVACMD is honored by jruby
export JAVACMD=`which drip`
# Drip preloads our codez
export DRIP_INIT_CLASS=org.jruby.main.DripMain
export DRIP_INIT="" # Needs to be non-null for drip to use it at all!

# settings from: https://github.com/jruby/jruby/wiki/Improving-startup-time
export JRUBY_OPTS="-J-XX:+TieredCompilation -J-XX:TieredStopAtLevel=1 -J-noverify -X-C"


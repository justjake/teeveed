# patching the following issue cowboy style
# https://github.com/cowboyd/therubyrhino/commit/a3eeda48b291f208ae4d27248eb111425f196ec6
module Rhino
  FILE = __FILE__
  JAR_VERSION = '1.7.4'; version = JAR_VERSION.split('.')
  jar_file = "rhino-#{version[0]}.#{version[1]}R#{version[2]}.jar"
  JAR_PATH = File.expand_path("./#{jar_file}", File.dirname(__FILE__))
end

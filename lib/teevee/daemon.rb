module Teevee

  # The daemon module uses the rest of the Teevee library to generate and respond
  # to media requests, update a library, etc.
  # it should eventually be totally configurable from a single DSL config file
  module Daemon
  end

end

require 'teevee/daemon/intent_controller'
require 'teevee/daemon/cli'
require 'teevee/daemon/remote'

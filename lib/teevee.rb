###
# Teevee - a natural language interface show-starter
###

require 'rubygems'
require 'bundler'
Bundler.setup

require 'teevee/wit'
require 'teevee/library'

require 'pry'



# Teevee is a library for implementing media center daemons with natural language
# user interfaces. NLI is based on Wit.ai.
module Teevee

  # A simple Pry command line for interacting with Teevee
  class CLI
    def initialize
      @wit = Wit.new
    end

    def say(msg)
      @wit.message(msg)
    end

    def interact
      binding.pry
    end
  end

end

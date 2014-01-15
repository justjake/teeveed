# -*- encoding : utf-8 -*-
###
# Teevee - a natural language interface show-starter
###

require 'rubygems'
# no longer use Bundler - it fights with Java things

# Teevee is a library for implementing media center daemons with natural language
# user interfaces. NLI is based on Wit.ai.
module Teevee

  # set the log level to something
  def self.log_level=(int)
    @log_level = int
  end

  def self.log_level
    @log_level
  end

  def self.log(level, *texts)
    if level <= log_level
      puts " % Teevee #{level}) " + texts.join(': ')
    end
  end
end

# NLP api
require 'teevee/wit'

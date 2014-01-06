###
# Teevee - a natural language interface show-starter
###

require 'rubygems'
require 'bundler'
Bundler.setup


# Teevee is a library for implementing media center daemons with natural language
# user interfaces. NLI is based on Wit.ai.
module Teevee
end

# NLP api
require 'teevee/wit'

# indexed library
require 'teevee/searchable'
require 'teevee/library'
require 'teevee/migrations'

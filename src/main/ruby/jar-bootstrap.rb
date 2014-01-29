#!/usr/bin/env ruby
# -*- encoding : utf-8 -*-
# this file is run by JRuby in the compiled jar.
# it is expected to be in the root of the jar, next to teeveed.rb
require 'rhino_patch'

# boot our application
require 'teevee/daemon'
Teevee::Daemon.main(ARGV)
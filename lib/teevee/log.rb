# -*- encoding : utf-8 -*-
# simple logging

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
      puts "[#{level}] Teevee --> " + texts.join(': ')
    end
  end
end

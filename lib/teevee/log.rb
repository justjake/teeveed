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
      puts " % Teevee #{level}) " + texts.join(': ')
    end
  end
end
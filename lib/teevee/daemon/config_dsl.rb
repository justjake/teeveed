# -*- encoding : utf-8 -*-
# loads user configs and instance-evals them
require 'pathname'
require 'active_support/core_ext/numeric/time'

module Teevee
  module Daemon
    class ConfigDSL

      # occurs when the config does not define a required section
      class ConfigError < StandardError; end

      class SectionConstructor
        attr_reader :sections
        def initialize(&block)
          @sections = {}
          instance_eval(&block)
        end

        # section 'Television' => :Episode
        # map a library sub-path to a Media type
        # <path under library root> => :<class name>
        def section(path_to_class)
          @sections = @sections.merge(path_to_class)
        end
      end


      def self.load(filename)
        config = self.new
        config.instance_eval(File.read(filename), filename)
        config
      end

      def initialize
        # list of unloaded plugin names and thier options
        @plugins_and_options = []
        # TODO - marge this with command line opts
        @options = {}
        # list of types [(Symbol), times (String), actions (Proc)]
        @schedules = []
        @root_specs = {}
      end

      # @return all instance variables as a hash
      def to_hash
        res = {}
        self.instance_variables.each do |varname|
          res[varname.to_s[1..-1].to_sym] = instance_variable_get(varname)
        end
        res
      end


      ### Config DSL

      # Log messages during your config load
      def log(level, *texts)
        Teevee.log(level, 'config', *texts)
      end

      # Configure the database connection
      # @param uri [String] a JDBC PostgreSQL URI
      def database(uri)
        raise ConfigError, 'bad database URL format' unless uri.start_with? 'jdbc:postgresql'
        @database_uri = uri
      end

      # Set the Wit.ai API token
      # @param token [String] a valid OAuth2 bearer token for
      #                       the 'teeveed' Wit.ai instance
      def wit_token(token)
        @options[:wit_token] = token
      end

      # Configure a library. Currently only one library is supported.
      # A library is a directory that contains different sections that hold your
      # media files.
      #
      # Ex: /mnt/storage is a library, /mnt/storage/Movies, /mnt/storage/Television
      #   are two sections in /mnt/storage
      #
      #   library '/mnt/storage' do
      #     section 'Movies' => :Movie
      #     section 'Television' => :Episode
      #   end
      #
      # if more than one library is configured, teeveed's behavior is undefined.
      #
      # @param path [String] path to the root of the library.
      def library(path, &block)
        pathname = Pathname.new(path).realpath
        sects = SectionConstructor.new(&block).sections
        @root_specs[pathname.to_s] = sects
      end

      # Request a plugin
      # @param name [Symbol, String] symbol: a plugin in teevee/plugins/
      #                              string (with /s): a seperate file
      # @param options [Hash] options to pass to the plugin
      def plugin(name, options = nil)
        @plugins_and_options << [name, options]
      end

      # perform a scan before daemon startup
      def scan_at_startup
        @options[:scan] = true
      end

      # Set the verbosity of this teeveed instance
      # @param level [Integer] log level
      def log_level(level)
        @options[:verbosity] = level
      end

      # easy scheduled tasks
        # @param type [Symbol] :every, :on, ... see Rufus Scheduler
        # @param time [Integer, String] see Rufus Scheduler, Integers will be
        #                               be converted to seconds
        # @param &block the scheduled action to run
      def schedule(type, time, &block)
        # convert more complex counts into seconds
        if [:in, :every].include? type and !(time.is_a? String)
          time = "#{time.to_i}s"
        end

        @schedules << [type, time, block]
      end

    end
  end
end

# -*- encoding : utf-8 -*-
# program entrypoint and main function
# publicly requireable

require 'rubygems'
require 'pathname'
require 'trollop'
require 'rufus-scheduler' # could be moved to plugin but too complicated
require 'sequel'
Sequel.extension :core_extensions

require 'teevee/daemon/config_dsl'
require 'teevee/daemon/scheduled_runtime'
require 'teevee/log'

module Teevee
  # The Daemon module contains just the classes needed for option and
  # config parsing and the main function
  module Daemon
    RUN_THEN_EXIT_OPTIONS = [:scan, :cli, :migrate].freeze
    COMMAND_LINE_OPTIONS = Trollop::Parser.new do
      ### Settings
      opt :config, 'config file to load', :default => "#{ENV['HOME']}/.teeveed.conf.rb"
      opt :verbosity, 'set the log level', :type => :int, :default => 3

      ### One-time tools
      opt :scan, 'scan library at boot'
      opt :cli, 'boot into a local pry session'

      opt :migrate, 'apply migrations folder, from --from to --to', :type => :string
      opt :from, 'migrate starting here', :type => :int
      opt :to, 'migrate to here', :type => :int

      ### Main run loops (provided by plugins)
      opt :remote, 'Launch remote pry debug server'

      opt :web, 'Launch webserver'
      opt :ip, 'listening ip for the web ui'
      opt :port, 'listening port for the web ui'
      opt :wit_token, 'wit oauth2 access token. Can also be provided via $WIT_ACCESS_TOKEN', :type => :string

      opt :hud, 'enable on-screen user interface'

      conflicts(*RUN_THEN_EXIT_OPTIONS)
    end



    def self.parse_options(args)
      # block displays errors and help on exception
      opts = Trollop::with_standard_exception_handling(COMMAND_LINE_OPTIONS) do
        COMMAND_LINE_OPTIONS.parse(args)
      end
      # read WIT_ACCESS_TOKEN from ENV if it wasn't an argument
      opts[:wit_token] ||= ENV['WIT_ACCESS_TOKEN']

      # --from requires a --to
      if opts[:from] and not opts[:to]
        COMMAND_LINE_OPTIONS.die :from, '--from requires --to'
      end

      # make sure --config exists
      unless Pathname.new(opts[:config]).file?
        COMMAND_LINE_OPTIONS.die(:config, 'config must be a file')
      end

      opts
    end

    # like a Java main. Start teeveed
    # @param args [Array<String>] main args
    def self.main(args)
      opts = parse_options(args)
      Teevee.log_level = opts[:verbosity]
      Teevee.log(5, 'boot', 'loading user config...')
      config = Teevee::Daemon::ConfigDSL.load(opts[:config]).to_hash

      ### enact settings
      opts = opts.merge(config[:options])
      Teevee.log_level = opts[:verbosity]
      Teevee.log(5, 'boot', 'creating application')

      Sequel.connect(config[:database_uri])
      # REQUIRE EVERY NON-DAEMON, NON-PLUGINS THING
      require 'teevee'

      ### teevee objects
      path = config[:root_specs].keys.first
      root_spec = config[:root_specs][path]
      # transform any symbols to Media sublcasses
      root_spec.each do |path, classname|
        if classname.is_a? Symbol or classname.is_a? String
          root_spec[path] = Teevee::Library.const_get(classname)
        end
      end

      root = Teevee::Library::Root.new(path, config[:root_specs][path])
      indexer = Teevee::Library::Indexer.new(root)
      app = Teevee::Application.new(root, indexer, opts[:wit_token], opts)

      ### load plugins
      config[:plugins_and_options].each do |name_opts|
        instance = Teevee::Plugin.load_and_instantiate(name_opts[0], app, name_opts[1])
        app.plugins << instance
      end


      ### run-then-exit #############################################
      run_then_exit = false
      RUN_THEN_EXIT_OPTIONS.each{|tool| run_then_exit = tool if opts[tool]}
      if run_then_exit
        Teevee.log(3, 'tool', "running tool #{run_then_exit}")

        case run_then_exit
          when :scan
            indexer.scan(root.path)
          when :cli
            require 'teevee/plugins/remote_debugger'
            cli = Teevee::Plugins::RemoteDebugger.new(app, {})
            cli.run_local
          when :migrate
            Sequel.extension :migration
            Teevee.log 1, 'migrations', "Running migrations in #{opts[:migrate]} to:#{opts[:to]}, from:#{opts[:from]}"
            Sequel::Migrator.apply(Sequel::DATABASES[0], opts[:migrate], opts[:to], opts[:from])
          else
            raise 'unreachable else in run_then_exit'
        end

        Teevee.log(3, 'tool', "#{run_then_exit} finished")
        exit 0
      end


      ### daemon ####################################################
      threads = []

      # scheduled actions
      if config[:schedules].length > 0
        Teevee.log(1, 'daemon', 'starting schedule')
        scheduler = Rufus::Scheduler.new
        scheduler.pause
        config[:schedules].each do |spec|
          action = Proc.new {ScheduleRuntime.new(app).instance_eval(&spec[2])}
          scheduler.send(spec[0], spec[1], &action)
        end
        threads << scheduler
        scheduler.resume
      end

      # plugins that provide daemon functionality
      # run em in threads
      Teevee.log(1, 'daemon', "starting #{app.plugins.length} plugins")
      app.plugins.each do |plugin|
        threads << Thread.new do
          Teevee.log(2, 'daemon', "starting #{plugin.class.to_s}")
          plugin.run!
          Teevee.log(2, 'daemon', "finished #{plugin.class.to_s}")
        end
      end

      # wait for all plugins to finish (never happens ;)
      threads.each{|t| t.join}
      Teevee.log(1, 'exit', 'shutting down')
      exit 0
    end
  end
end

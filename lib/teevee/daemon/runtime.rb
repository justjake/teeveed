# -*- encoding : utf-8 -*-
require 'active_support/core_ext/numeric/time'
require 'rufus-scheduler'

require 'sequel'
Sequel.extension :core_extensions

module Teevee
  module Daemon
    # a scope for performing configuration
    module Runtime
      include Teevee::Library

      # occurs when the config does not define a required section
      class ConfigError < StandardError; end

      class SectionConstructor
        attr_reader :sections
        def initialize(&block)
          @sections = {}
          instance_eval(&block)
        end

        # section 'Television' => Episode
        def section(opts)
          @sections = @sections.merge(opts)
        end
      end

      # sets the options as they were before user config was loaded
      def initial_options(opts)
        @original_opts = opts
        @options = opts.dup
      end

      # Load a plugin
      # @param plugin_name [String, Symbol] filename of plugin in /teevee/plugins/
      # @param opts [Hash] options for the plugin
      def plugin(plugin_name, opts = {})
        @plugins ||= []
        instance = Teevee::Plugin.load_and_instantiate(plugin_name.to_s, opts)
        @plugins << instance
      end

      def enable_remote_debugging
        @options[:remote] = true
      end

      def enable_webui
        @options[:web] = true
      end

      def enable_hud
        @options[:hud] = true
      end

      def scan_at_startup
        @options[:scan] = true
      end

      def wit_token(token)
        @options[:wit_token] = token
      end

      # set the log level
      # 0 = only critical
      # 4 = prunings
      # 5 = item scans
      def log_level(int)
        Teevee.log_level = int
      end

      # pass through for configs
      # intended to be used from a scheduled thing
      def log(level, *texts)
        Teevee.log(level, 'config', *texts)
      end

      # turn on and configure the webui
      def webui(opts)
        enable_webui
        @options = @options.merge(opts)
      end

      # connect the database
      # database connection in the form of a JDBC connection string
      # see http://jdbc.postgresql.org/documentation/80/connect.html
      def database(uri)
        Sequel.connect(uri)
        @finalized = true

        # now that that database has been loaded, we can require the Library
        require 'teevee/library/media'
      end

      # define the library
      def library(path, &block)
        # ensures real path
        pathname = Pathname.new(path).realpath
        sects = SectionConstructor.new(&block)
        @root = Teevee::Library::Root.new(pathname.to_s, sects.sections)
        @indexer = Teevee::Library::Indexer.new(@root)
      end

      # easy scheduled tasks
      def schedule(type, time, &block)
        if @scheduler.nil?
          @scheduler = Rufus::Scheduler.new
          @scheduler.pause
        end

        # convert more complex counts into seconds
        if [:in, :every].include? type and !(time.is_a? String)
          time = "#{time.to_i}s"
        end

        @scheduler.send(type, time, &block)
      end

      # intended for scheduling index sweeps
      def scan_for_changes(path)
        path = Pathname.new(path)
        path = @root.pathname + path if path.relative?
        @indexer.scan(path)
      end

      # destroy everything and start over
      def rebuild_index
        Library::Media.all.destroy
        scan_for_changes(@root.path)
      end

      def boot!
        opts = @options

        # guards
        raise ConfigError, 'No library defined.' unless @root
        raise ConfigError, 'No database connected.' unless @finalized
        if opts[:web] and not opts[:wit_token]
          Trollop::die :wit_token, 'the web ui requires a wit token'
        end

        Teevee.log 0, 'boot', 'STARTING TEEVEED'

        ### Tools ###################################################

        # --migrate - perform migrations and exit
        if opts[:migrate]
          # load extension for Sequel::Migrator
          Sequel.extension :migration
          Teevee.log 1, 'migrations', "Running migrations in #{opts[:migrate]} to:#{opts[:to]}, from:#{opts[:from]}"

          Sequel::Migrator.apply(Sequel::DATABASES[0], opts[:migrate], opts[:to], opts[:from])

          exit 0
        end

        Teevee.log 5, 'boot', 'creating application'
        app = Teevee::Application.new(@root, @indexer, @plugins, opts)

        # --scan or scan_at_startup
        if opts[:scan]
          Teevee.log 1, 'boot', 'running scan'
          app.indexer.scan(app.root.path)
        end

        # --cli
        if opts[:cli]
          Teevee.log 1, 'boot', 'opening CLI'
          CLI.new(Daemon.instance).interact!
          exit 0
        end


        ### Daemon ##################################################

        threads = []

        if @scheduler
          threads << @scheduler
          @scheduler.resume
        end

        # --web - natural language interface via mobile web
        if opts[:web]
          Teevee.log 1, 'boot', 'starting web remote'
          # start the webserver for the remote in a thread
          web = Thread.new do
            WebRemote.set :bind, opts[:ip]
            WebRemote.set :port, opts[:port]
            WebRemote.run!
          end
          threads << web
        end

        # --remote - remote debugging interface pry-remote
        if opts[:remote]
          # start pry-remote in a thread
          Teevee.log 1, 'boot', 'starting ruby remote debugger'
          debug = Thread.new do
            while true do
              CLI.new(Daemon.instance).interact_remote!
            end
          end
          threads << debug
        end

        # --hud - show on-screen display
        if opts[:hud]
          require 'teevee/daemon/hud'
          hud = Thread.new do
            Teevee::Daemon::HUD.start
          end
          threads << hud
        end

        Teevee.log 1, 'boot', 'daemon started successfully.'

        # wait for our server (forever)
        threads.each {|t| t.join}
        Teevee.log 1, 'exit', 'shutting down.'
        exit 0

      end # boot!

    end # Runtime
  end
end


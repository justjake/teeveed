require 'active_support/core_ext/numeric/time'

module Teevee
  module Daemon
    # a scope for performing configuration
    module Runtime

      # occurs when the config does not define a required section
      class ConfigError < StandardError; end
      include Teevee::Library

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

      def initial_options(opts)
        @options = opts
      end

      def enable_remote_debugging
        @options[:remote] = true
      end

      def enable_webui
        @options[:web] = true
      end

      def scan_at_startup
        @options[:scan] = true
      end

      # turn on and configure the webui
      def webui(opts)
        enable_webui
        @options = @options.merge(opts)
      end

      # connect the database
      def database(uri)
        DataMapper.setup(:default, uri)
        @finalized = true
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
        # guards
        raise ConfigError, "No library defined." unless @root
        raise ConfigError, "No database connected." unless @finalized

        puts "STARTING TEEVEED BOOT PROCESS"
        # lots of this code comes from the old teeveed.rb
        opts = @options

        # finish this puppy up
        DataMapper.finalize

        # perform migrations and exit
        if opts[:migrate]
          DataMapper::Logger.new(STDOUT, :debug)
          DataMapper.logger.debug( "Starting migrations, up: #{opts[:up]}, down: #{opts[:down]}" )

          # we aren't using transactions in the migrations, so.... do this instead when things
          # blow up and state gets messy :(
          # TODO switch migrations to transactions
          if opts[:trash]
            adapter = DataMapper.repository(@repository).adapter
            adapter.execute('DROP TABLE migration_info;')
          end

          migrations = Teevee::Migrations::generate(Teevee::Library::Media)
          ups = migrations.select{|m| opts[:up].include? m.position }
          downs = migrations.select{|m| opts[:down].include? m.position }

          downs.reverse.each {|m| m.perform_down}
          ups.each {|m| m.perform_up}

          exit 0
        end

        puts "creating application"
        app = Daemon.instance = Daemon::Application.new(@root, @indexer, opts)

        if opts[:scan]
          puts "running scan"
          app.indexer.scan(app.root.path)
        end

        if opts[:cli]
          CLI.new(Daemon.instance).interact!
          exit 0
        end

        threads = []

        if @scheduler
          threads << @scheduler
          @scheduler.resume
        end

        # --web - natural language interface via mobile web
        if opts[:web]
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
          debug = Thread.new do
            while true do
              CLI.new(Daemon.instance).interact_remote!
            end
          end
          threads << debug
        end

        # wait for our server (forever)
        threads.each {|t| t.join}

      end # boot!

    end # Runtime
  end
end


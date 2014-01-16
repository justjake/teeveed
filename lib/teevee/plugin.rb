module Teevee

  # API for creating plugins
  module Plugin

    # Just lists the contents of /teevee/plugins/
    def self.built_in
      require 'pathname'
      (Pathname.new(__FILE__).parent + 'plugins').children(false)
        .map{|fn| fn.to_s}
    end


    # Load a plugin from disk
    # You can specify a plugin outside of the built-in plugin folders
    # by supplying a string (with at least one '/') instead of a Symbol
    # @param plugin_name [String, Symbol]
    def self.load(plugin_name)
      if plugin_name.is_a? String and plugin_name.include? '/'
        require plugin_name
      else
        require "teevee/plugins/#{plugin_name.to_s}"
      end
      Teevee::Plugins::LOADED_PLUGINS.last
    end

    # Set up a newly-loaded plugin. Mixes the pluin's IntentHandlers
    # into IntentController.
    def self.setup(klass)
      Teevee::IntentController.send(:include, klass::IntentHandlers)
    end

    # perform library includes and stuff. Intended to be called from Runtime
    # @param opts [Hash]
    # @return [is_a? Teevee::Plugin::Base] instantiated plugin
    def self.load_and_instantiate(plugin_name, app, opts)
      latest_plugin = self.load(plugin_name)
      setup(latest_plugin)
      latest_plugin.new(app, opts)
    end

    # Base class for teeved plugins.
    class Base
      # this is how plugins end up in Teevee::Plugins::LOADED_PLUGINS
      def self.inherited(child_class)
        Teevee::Plugins::LOADED_PLUGINS << child_class
      end

      # Empty module
      # will be over-written in subclasses to provide new intent handlers
      module IntentHandlers
      end

      ### API
      attr_reader :app

      # Log information from your plugin.
      # @param level [Integer] log level. Lower is more likely to be logged
      # @param texts [String] Sections/messages to log
      def log(level, *texts)
        Teevee.log(level, self.class.to_s, *texts)
      end

      ### Methods to override

      # @param app [Teevee::Applicatio]
      # @param opts [Hash]
      def initialize(app, opts)
        log(6, "instantiated plugin #{self.class.to_s}", opts.to_s)
        @app = app
      end

      ### Hooks - optional

      # Your plugin's daemon thread, if you need one.
      # Called in a thread at the end of the boot process during
      # daemonization.
      # When all plugin threads return, teeveed will exit.
      def run!
      end

      # Run (in order of plugin definition) on any intent coming into
      # the IntentController.
      # This intent may act as middleware, meaning you can return
      # any intent you want to and it will be passed down the line of
      # before_intent_handlers and then handed off to the IntentController
      # itself.
      #
      # usually just a good idea to return the intent as-it-was, though
      #
      # @param [Teevee::Daemon::IntentController] controller
      # @param [Teevee:;Wit::Intent] intent
      # @return [Teevee::Wit::Intent]
      def before_intent_handler(controller, intent)
        return intent
      end

      # Run (in order of plugin definition) on the result of any
      # intent handled by the intent controller
      # again, acts as middleware on the return result
      #
      # @param [Teevee::Daemon::IntentController] controller
      # @param [Any] result
      # @return [Any] result
      def after_intent_handler(controller, result)
        return result
      end

    end # end Base

    # Plugins list with shorthand selectors
    class List < Array
      # selects all objects that respond to the given method
      # @param meth_name [Symbol] method to respond to
      def with_method(meth_name)
        self.select{|plugin| plugin.respond_to? meth_name}
      end
    end
  end

  # nearly empty namespace where plugin modules are stored.
  # not sure if this is nescessary
  module Plugins
    # when we load a plugin, it's class will be appended here.
    LOADED_PLUGINS = []
  end
end
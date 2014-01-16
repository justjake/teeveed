module Teevee

  # API for creating plugins
  module Plugin

    # Just lists the contents of /teevee/plugins/
    def self.built_in
      require 'pathname'
      (Pathname.new(__FILE__).parent + 'plugins').children(false)
        .map{|fn| fn.to_s}
    end

    # perform library includes and stuff. Intended to be called from Runtime
    # You can specify a plutin outside of the built-in plugin folders
    # by supplying a string (with at least one '/') instead of a Symbol
    # @param plugin_name [String, Symbol]
    # @param opts [Hash]
    # @return [is_a? Teevee::Plugin::Base] instantiated plugin
    def self.load_and_instantiate(plugin_name, opts)
      if plugin_name.is_a? String and plugin_name.include? '/'
        require plugin_name
      else
        require "teevee/plugins/#{plugin_name.to_s}"
      end
      latest_plugin = Teevee::Plugins::LOADED_PLUGINS.last
      setup(lastest_plugin)
      latest_plugin.new(opts)
    end

    # Set up a newly-loaded plugin
    def self.setup(klass)
      Teevee::IntentController.send(:include, klass::IntentHandlers)
    end

    # Base class for teeved plugins.
    class Base
      # this is how plugins end up in Teevee::Plugins::LOADED_PLUGINS
      def self.inherited(child_class)
        Teevee::Plugins::LOADED_PLUGINS << child_class
      end

      # Gets the latest (and usually only) instance of your plugin
      # I haven't decided if this API is advisable
      def self.instance
        @@instance
      end

      def initialize(opts)
        @@instance = self
        log(6, "instantiated plugin #{self.class.to_s}", opts.to_s)
      end

      # Log information from your plugin.
      # @param level [Integer] log level. Lower is more likely to be logged
      # @param texts [String] Sections/messages to log
      def log(level, *texts)
        Teevee.log(level, self.class.to_s, *texts)
      end

      # Empty module
      # will be over-written in subclasses to provide new intent handlers
      module IntentHandlers
      end
    end

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
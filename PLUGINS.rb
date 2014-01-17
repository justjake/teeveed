%q{
# Design Document for teeveed Plugins

Plugins allow for clean dilineation of features into different,
independent files. Plugins are files that live in `lib/teeveed/plugis/`
that define an entire new feature.

## PLUGIN REACTORING TODOS

TODO: rework Runtime as a ConfigDSL class and load user config with
      an instance_eval

TODO: create app before loading user config so we can pass it immidatly
      to plugins in DSL phase (or do alternative??)

TODO: need to work in the web_ui and heads_up_display plugins
      so that boot procedes as normal

Through a plugin, you may:

- boot a thread at daemon startup
- handle new Wit.ai intents by providing new methods for the
  IntentController
- hood intent handling to provide user interface updates
  before and after intent handlers are performed

Plugins are treated as singletons. One instance of your plugin
will be created after it your plugin file is required.

# Example plugin definition:
}

module Teevee
  # you can define your plugin in any namespace.
  # the teeveed built-in plugins use Teevee::Plugins
  module Plugins
    # Teevee::Plugins::Base does one essential thing:
    # it adds your plugin
    # to the list of loaded plugins at Teevee::Plugins::LoadedPlugins
    # so that your hooks and threads can be run.
    #
    # Your plugin filename and classname are linked. The user will
    # specify your plugin during configuration using the `plugin`
    # method in teevee/daemon/sconfig_dsl.rb:
    # @example:
    #   plugin :my_plugin, :opt1 => 'hi', :opt2 => 'hello'
    # When this happens, teeveed will require 'teevee/plugins/my_plugin'
    # basically, camelcase to snake case.
    # when you plugin is loaded, it becomes the last thing in LOADED_PLUGINS,
    # which is then instantiated and appended to the app's plugins field.
    #
    # NOTE THAT THIS IS Teevee::Plugin::Base. Plugin, not Plugins!
    class MyPlugin < Teevee::Plugin::Base

      # Called when the plugin is activated by the user configuration
      # at application boot.
      # configure should store your options somewhere but not start any
      # persistent actions in threads or anything
      # @param [Hash] opts - an options hash the user provides
      def initialize(opts)
        super(opts) # reccomended
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

      ### Intent Handlers - optional

      # submodule for adding Wit.ai intent handlers. This module will
      # be included directly into Teevee::Daemon::IntentController,
      # so it should have only sanitary methods in it
      #
      # Methods in IntentHandlers should have the same name as the
      # intent type they should handle, eg, for a :foobar intent,
      # you define a method foobar(intent)
      module IntentHandlers
        # all intent handlers have the following signature:
        # param [Teevee::Wit::Intent] intent - the intent you will handle
        def foobar(intent)
          raise 'not implemented'
        end
      end

    end
  end
end





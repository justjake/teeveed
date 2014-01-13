# -*- encoding : utf-8 -*-
require 'java'

module Teevee
  module Daemon
    # the HUD module manages a single instance of the JavaFX on-screen display
    # implemented in org.teton_landis.hud.HeadsUpDisplay.
    #
    # since modifications to the JavaFX user interface can happen only on the
    # JavaFX application thread, all changes to the HUD have to happen inside
    # Procs that are passed to the JavaFX Platform.runLater method for async
    # execution.
    module HUD
      AppClass = org.teton_landis.jake.hud.HeadsUpDisplay
      Platform = javafx.application.Platform

      raise LoadError, "Couldn't load org.teton_landis.jake.hud.HeadsUpDisplay" if AppClass.nil?
      raise LoadError, "Couldn't load javafx.application.Platform" if Platform.nil?

      # grabs the latest instance of HeadsUpDisplay.
      # @return [org.teton_landis.jake.hud.HeadsUpDisplay, Nil]
      def self.java_instance
        AppClass.instance
      end

      # Start the JavaFX user interface on the current thread.
      # should usually be run off the main thread,
      def self.start
        AppClass.main([])
      end

      # Perform an action on the JavaFX application thread.
      # @yieldparam [org.teton_landis.jake.hud.HeadsUpDisplay] hud current HUD instance
      def self.with_hud(&block)
        hud = java_instance
        # Proc.new not strictly required, but helps solve IDEA worries
        (Platform.runLater do
          block.call(hud)
        end)

      end
    end
  end
end

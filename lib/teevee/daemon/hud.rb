# -*- encoding : utf-8 -*-
require 'java'

module Teevee
  module Daemon
    # the HUD class manages a single instance of the JavaFX on-screen display
    # implemented in org.teton_landis.hud.HeadsUpDisplay.
    #
    # since modifications to the JavaFX user interface can happen only on the
    # JavaFX application thread, all changes to the HUD have to happen inside
    # Procs that are passed to the JavaFX Platform.runLater method for async
    # execution. Therefor the bang methods should only be called within an
    # #update block
    class HUD
      HeadsUpDisplay = org.teton_landis.jake.hud.HeadsUpDisplay
      Platform = javafx.application.Platform

      raise LoadError, "Couldn't load org.teton_landis.jake.hud.HeadsUpDisplay" if HeadsUpDisplay.nil?
      raise LoadError, "Couldn't load javafx.application.Platform" if Platform.nil?

      HIDES_MUTEX = Mutex.new
      PENDING_HIDES = []

      # pretty
      DAIMOND = '♦'
      RIGHT_ARROW = '→'

      # grabs the latest instance of HeadsUpDisplay.
      def self.java_instance
        HeadsUpDisplay.instance
      end

      # Start the JavaFX user interface on the current thread.
      # should usually be run off the main thread,
      def self.start
        HeadsUpDisplay.main([])
      end

      def initialize(enabled)
        @enabled = enabled
        @ui = self.class.java_instance()
      end

      def enabled?
        @enabled
      end

      # Perform an action on the JavaFX application thread.
      # the action is only performed if the HUD is enabled in application options
      # @yieldparam [org.teton_landis.jake.hud.HeadsUpDisplay] hud current HUD instance
      def update(&block)
        if enabled?
          (Platform.runLater do
            block.call(@ui)
          end)
        end
      end

      # push an alert onto the heads-up display
      # @param [Array<String>] style_classes CSS for the whole alert text
      # @param [Array<Array<String>>] content_with_styles ['some text content', 'styleclass1', 'styleclass2', ...]
      def push_alert!(style_classes, *content_with_styles)
        @ui.pushAlert(style_classes, *content_with_styles)
      end

      # clear the heads-up display of all text
      def clear_alerts!
        @ui.clearAlerts
      end

      # Hide the heads-up display
      def hide!
        @ui.hideHud
      end

      # Show the heads-up display
      def show!
        cancel_hides
        @ui.showHud
      end

      # schedules a new thread hide, overriding all previous hides
      def hide_in(after_duration)
        cancel_hides
        HIDES_MUTEX.synchronize do
          PENDING_HIDES << Thread.new do
            sleep(after_duration)
            update do
              self.hide!
            end
          end
        end
      end

      # Cancel all future hides
      def cancel_hides
        HIDES_MUTEX.synchronize do
          PENDING_HIDES.each {|thread| thread.kill }
          PENDING_HIDES.clear
        end
      end


      # print "Found <X>" or "Found 24 files starting with <X>"
      # @param res [Any#friendly_name, Enumerable<Any#friendly_name>] results from performing an intent
      def push_results!(res)
        if res.respond_to? :friendly_name
          alert = [['Found'], [res.friendly_name, 'entity']]
        elsif res.is_a? Enumerable
          alert = [['Found'], [res.length.to_s, 'entity'], ['hits starting with'], [res[0].friendly_name, 'entity']]
        elsif res.nil?
          alert = [['No results found.']]
        else
          raise ArgumentError, 'must respond_to? :friendly_name or be enumerable of such.'
        end

        push_alert!(['small'], *alert)
      end


      # update the hud to reflect the scanned intent
      # @param [Intent] intent the most recent user intent
      def push_intent!(intent)
        if intent.type.nil?
          styled_intent = [["#{DAIMOND} no intent detected"]]
        else
          styled_intent = [["#{DAIMOND} Intent:"], [intent.type.to_s.gsub(/_/, ' '), 'intent']]
          if intent.entities[:action]
            styled_intent << [RIGHT_ARROW]
            styled_intent << [intent.entities[:action].value, 'action']
          end
          styled_intent << ["with #{intent.confidence} confidence"] if intent.confidence < 0.7
        end
        body = _intent_to_alert(intent)

        push_alert!(['small'], *styled_intent)
        push_alert!(['large'], *body)
      end


      private

      # returns the sort of array-of-array-of-strings thing that HeadsUpDisplay.pushAlert takes
      # as its second parameter for a given intent. Basically splits out all the entities
      # and puts those in thier own words
      def _intent_to_alert(intent)
        if (intent.entities || {}).keys.count > 0
          res = []
          entities = intent.entities.values.select{|ent| ent.start} .sort{|a, b| a.start <=> b.start }
          prev_end = 0
          entities.each { |ent|
            # non-entity prefix
            res << [intent.body[prev_end...ent.start].strip]
            # entity body
            res << [ent.body, 'entity']

            prev_end = ent.end
          }

          return res
        end

        # otherwise just the un-marked-up body
        return [[intent.body]]
      end

    end
  end
end

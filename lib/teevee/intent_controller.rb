# -*- encoding : utf-8 -*-
module Teevee

  # An intent we don't know how to deal with
  class UnknownIntent < StandardError; end

  # we haven't done this yet
  class Unimplemented < StandardError; end

  # when there's not enough information in the intent to search
  class NotEnoughData < StandardError; end

  # the IntentController takes an intnet and carries out the actions needed
  # to bring it to fruition
  class IntentController

    def initialize(application)
      @app = application
    end

    # add wait-time while starting VLC server.
    # this makes things very slow, the web ui should return first.

    def plugins
      @app.plugins
    end

    def handle_intent(intent)
        log 3, "Handling a #{intent.type.to_s} intent"

        plugins.each{|plg| intent = plg.before_intent_handler(self, intent)}
        begin
          res = self.send(intent.type, intent)
        # TODO: is there a more correct way to allow plugins to handle errors?
        rescue StandardError => err
          plugins.each{|plg| err = plg.error_intent_handler(self, err)}
          raise err unless err.nil?
        end

        plugins.each{|plg| res = plg.after_intent_handler(self, res)}

        return res
    end


    def log(level, *things)
      Teevee.log(level, 'IntentController', *things)
    end

  end
end

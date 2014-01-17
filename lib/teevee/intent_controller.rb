# -*- encoding : utf-8 -*-
module Teevee

  # An intent we don't know how to deal with
  class UnknownIntent < StandardError; end

  # we haven't done this yet
  class Unimplemented < StandardError; end

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
      if self.respond_to? intent.type
        log 3, "Handling a #{intent.type.to_s} intent"

        plugins.each{|plg| intent = plg.before_intent_handler(self, intent)}
        res = self.send(intent.type, intent)
        plugins.each{|plg| res = plg.after_intent_handler(self, res)}

        return res
      end
      raise UnknownIntent, "Unknown intent: #{intent}"
    end


    def log(level, *things)
      Teevee.log(level, 'IntentController', *things)
    end

  end
end

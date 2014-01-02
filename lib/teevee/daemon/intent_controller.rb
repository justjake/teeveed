module Teevee
  module Daemon

    # An intent we don't know how to deal with
    class UnknownIntent < StandardError; end

    # we haven't done this yet
    class Unimplemented < StandardError; end

    # the IntentController takes an intnet and carries out the actions needed
    # to bring it to fruition
    class IntentController

      KNOWN_INTENTS = [
          :query_episode,
          :query_movie,
          :query_song,

          :find_hosers,
          :fix_mount_point
      ]

      def handle_intent(intent)
        raise UnknownIntent, "Unknown intent: #{intent}" unless KNOWN_INTENTS.include? intent.type
        raise Unimplemented, "unimplemented"
      end

    end
  end
end
require 'vlc-client'

module Teevee
  module Daemon

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

      def handle_intent(intent)
        if self.respond_to? intent.type
          return self.send(intent.type, intent)
        end
        raise UnknownIntent, "Unknown intent: #{intent}" unless KNOWN_INTENTS.include? intent.type
      end

      def query_episode(intent)
        # build query from definite paramters
        name_mapping = {
            :season => :season,
            :episode => :episode_num,
        }

        query = {}
        name_mapping.each do |wit, db|
          if intent.entities.include? wit
            query[db] = intent.entities[wit].value
          end
        end

        results = Teevee::Library::Episode.all(query)

        # fuzzy matching stuff
        if intent.entities.include? :title
          # title => search "show"
          episodes = results.search(intent.entities[:title].value, :search_indexes => [:show])
          results = episodes if episodes.length > 0
        end

        if intent.entities.include? :episode_name
          episodes = results.search(intent.entities[:episode_name].value, :search_indexes => [:title])
          results = episodes if episodes.length > 0
        end

        if results.length == 0
          return 'No results found.'
        end

        episode = results[0]
        if episode.attributes.include? :season and episode.attributes.include? :episode_num
          # we have a well-frormatted episode on our hands
          # build a playlist of the following episodes in the season
          season = Teevee::Library::Episdoe.all(
            :season => episode.season,
            :episode_num.gt => episode.episode_num,
            :order => [:episode_num.asc]
          ).to_a
          playlist = season.map{ |f| @app.root.pathname + f.relative_path}


          # do vlc things
          vlc = @app.vlc
          vlc.start unless vlc.running?
          vlc.clear # clear okaylist
          vlc.play((@app.root.pathname + episode.relative_path).to_s)
          playlist.each{|f| vlc.add_to_playlist(f) }

          return playlist
        end

        return episode

      end

    end
  end
end
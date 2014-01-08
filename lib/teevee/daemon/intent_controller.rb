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

      # add wait-time while starting VLC server.
      # this makes things very slow, the web ui should return first.
      def vlc
        _vlc = @app.vlc
        if _vlc.server.stopped?
          _vlc.server.start
          sleep 2 # wait for things to boot
        end
        _vlc
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

        query = {
            :order => [:season.asc, :episode_num.asc]
        }
        name_mapping.each do |wit, db|
          if intent.entities.include? wit
            query[db] = intent.entities[wit].value
          end
        end

        results = Teevee::Library::Episode.all(query)

        # fuzzy matching stuff
        if intent.entities.include? :title
          episodes = results.search(intent.entities[:title].value, :search_indexes => [:show])
          log "found #{episodes.length} show=#{intent.entities[:title].value}"
          results = episodes if episodes.length > 0
        end

        if intent.entities.include? :episode_name
          episodes = results.search(intent.entities[:episode_name].value, :search_indexes => [:title])
          log "found #{episodes.length} title=#{intent.entities[:episode_name].value}"
          results = episodes if episodes.length > 0
        end

        if results.length == 0
          return 'No results found.'
        end

        episode = results[0]

        if episode.attributes.include? :season and episode.attributes.include? :episode_num
          # we have a well-frormatted episode on our hands
          # build a playlist of the following episodes in the season
          season = Teevee::Library::Episode.all(
            :season => episode.season,
            :episode_num.gt => episode.episode_num,
            :order => [:episode_num.asc]
          ).to_a

          playlist = season.map{ |f| (@app.root.pathname + f.relative_path).to_s }

          Thread.new do
            vlc.connect
            vlc.clear # clear pkaylist
            vlc.play((@app.root.pathname + episode.relative_path).to_s)
            playlist.each{|f| vlc.add_to_playlist(f) }
          end

          return playlist
        end

        return episode
      end # query_episode

      def log(*things)
        puts "IntentController: #{things.join(': ')}"
      end

    end
  end
end
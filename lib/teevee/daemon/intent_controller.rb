# -*- encoding : utf-8 -*-
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
      # pretty
      DAIMOND = '♦'
      RIGHT_ARROW = '→'

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
          log 3, "Handling a #{intent.type.to_s} intent"

          update_hud(intent) if @app.config[:hud]

          return self.send(intent.type, intent)
        end
        raise UnknownIntent, "Unknown intent: #{intent}" unless KNOWN_INTENTS.include? intent.type
      end

      # returns the sort of array-of-array-of-strings thing that HeadsUpDisplay.pushAlert takes
      # as its second parameter for a given intent. Basically splits out all the entities
      # and puts those in thier own words
      def hud_annotated_intent(intent)
        if (intent.entities || {}).keys.count > 0
          res = []

          entities = intent.entities.values.select{|ent| ent.start}
            .sort{|a, b| a.start <=> b.start }

          prev_end = 0
          body = intent.body # this will be consumed
          entities.each { |ent|
            # non-entity prefix
            res << [body[prev_end..ent.start].strip]
            # entity body
            res << [ent.body, 'entity']

            prev_end = ent.end
          }

          return res
        end

        return [[intent.body]]
      end

      # update the hud to relect the scanned intent
      # @param [Intent] intent the most recent user intent
      def update_hud(intent)
        HUD.with_hud do |hud|
          if intent.type.nil?
            styled_intent = [["#{DAIMOND} no intent detected"]]
          else
            styled_intent = [["#{DAIMOND} Intent:"], [intent.type.to_s.gsub(/_/, ' '), 'action']]
            styled_intent << ["with #{intent.confidence}"] if intent.confidence < 0.7
          end
          body = hud_annotated_intent(intent)

          hud.clearAlerts
          hud.pushAlert(['small'], styled_intent)
          hud.pushAlert(['large'], body)

        end # end with_ud
      end

      def query_movie(intent)
        # fuzzy matching stuff
        if intent.entities.include? :title
          movies = Teevee::Library::Movie.search(intent.entities[:title].value, :search_indexes => [:title])
          log 4, "found #{movies.length} title=#{intent.entities[:title].value}"

          if movies.length > 0
            Thread.new do
              vlc.connect
              vlc.play @app.root.abs_path(movies[0].relative_path)
            end
            return movies[0]
          end

        end # end if
        'No results found.'

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
          log 4, "found #{episodes.length} show=#{intent.entities[:title].value}"
          results = episodes if episodes.length > 0
        end

        if intent.entities.include? :episode_name
          episodes = results.search(intent.entities[:episode_name].value, :search_indexes => [:title])
          log 4, "found #{episodes.length} title=#{intent.entities[:episode_name].value}"
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
            :episode_num.gte => episode.episode_num,
            :order => [:episode_num.asc]
          ).to_a

          playlist = season.map{ |f| @app.root.abs_path f.relative_path }

          Thread.new do
            vlc.connect
            vlc.clear # clear pkaylist
            playlist.each{|f| vlc.add_to_playlist(f) }
            vlc.play
          end

          return playlist
        end

        Thread.new do
          vlc.connect
          vlc.play @app.root.abs_path(episode.relative_path)
        end
        return episode

      end # query_episode

      def log(level, *things)
        Teevee.log(level, 'IntentController', *things)
      end

    end
  end
end

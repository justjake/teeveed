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
      @hud = HUD.new(@app.options[:hud])
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

        @hud.update do
          @hud.clear_alerts!
          @hud.push_intent!(intent)
          @hud.show!
        end

        res = self.send(intent.type, intent)

        @hud.update do
          @hud.push_results!(res)
          @hud.hide_in(30) # 30 seconds timeout
        end

        return res
      end
      raise UnknownIntent, "Unknown intent: #{intent}"
    end


    def query_movie(intent)
      # fuzzy matching stuff

      movies = Teevee::Library::Movie.dataset

      # filter on year
      if intent.entities.include? :year
        year = intent.entities[:title].value.to_i
        movies = movies.where(:year => year)
      end

      # filter on title
      if intent.entities.include? :title
        title = intent.entities[:title].value
        movies = movies.similar(:title, title)
        log 4, "found #{movies.count} title=#{title}"
      end # end if

      # success!
      if movies.count > 0
        Thread.new do
          vlc.connect
          vlc.play @app.root.abs_path(movies.first.relative_path)
        end
        return movies.first
      end

      # failure :(
      nil
    end

    def query_episode(intent)
      # build query from definite paramters
      # maps from wit_entity_name to database_column
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

      # filter on hard facts first
      results = Teevee::Library::Episode.where(query)

      # fuzzy matching stuff
      if intent.entities.include? :title # wit: title --> db: show
                                         # episodes = results.search(intent.entities[:title].value, :search_indexes => [:show])
        show_name = intent.entities[:title].value
        episodes = results.similar(:show, show_name)
        log 4, "found #{episodes.count} show=#{show_name}"
        results = episodes
      end

      if intent.entities.include? :episode_name
        episode_name = intent.entities[:episode_name].value
        # episodes = results.search(intent.entities[:episode_name].value, :search_indexes => [:title])
        episodes = results.similar(:title, episode_name)
        log 4, "found #{episodes.count} title=#{episode_name}"
        results = episodes
      end

      # failure
      if results.count == 0
        return nil
      end

      episode = results.first

      if episode.season and episode.episode_num
        # we have a well-formatted episode (with season data) on our hands
        # build a playlist of the following episodes in the season
        season = Teevee::Library::Episode.where(
            :show => episode.show,
            :season => episode.season,
        ).where{episode_num > episode.episode_num} .order(:episode_num).to_a

        playlist = season.map{ |f| @app.root.abs_path f.relative_path }

        Thread.new do
          vlc.connect
          vlc.clear # clear pkaylist
          playlist.each{|f| vlc.add_to_playlist(f) }
          vlc.play
        end

        return season
      end # end could get season

      Thread.new do
        vlc.connect
        vlc.play @app.root.abs_path(episode.relative_path)
      end

      episode
    end # query_episode

    def log(level, *things)
      Teevee.log(level, 'IntentController', *things)
    end

  end
end

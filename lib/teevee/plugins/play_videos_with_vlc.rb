# handles :query_movie and :query_episode
require 'vlc-client'

module Teevee
  module Plugins
    # core functionality: play back movies and TV shows with VLC
    class PlayVideosWithVLC < Teevee::Plugin::Base
      DEFAULT_VLC_PARAMS = {
          :host => '127.0.0.1',
          :port => 9999,
          :auto_start => false,
          :fullscreen => false,
          # these are conservative values, 0.6 and 0.1 may be better on
          # your i7 or whatever
          :startup_lag => 5, # seconds to wait for VLC to start up
          :connect_lag => 1  # seconds to wait for teeveed to connect to VLC
      }

      def initialize(app, opts)
        opts = DEFAULT_VLC_PARAMS.merge(opts || {})
        host = opts.delete :host
        port = opts.delete :port
        @fullscreen = opts.delete :fullscreen
        @startup = opts.delete :startup_lag
        @connect = opts.delete :connect_lag

        @vlc = VLC::System.new(host, port, opts)
        @mutex = Mutex.new
      end

      def should_fullscreen?
        @fullscreen
      end

      # Perform a block in a new thread with exclusive access to the VLC interface
      # @yields [vlc]
      def with_vlc(&block)
        Thread.new do
          @mutex.synchronize do
            block.call(_connected_vlc)
          end
        end
      end

      # ensures the instance of VLC you're looking at is real and connected.
      # does a bunch of sleeps so it shoudn't happen on the
      # main thread. I'm not proud of the sleeps here, but
      # its much better to keep the VLC state management simple for now.
      # TODO: repair with actual retry and async connections
      def _connected_vlc
        if @vlc.server.stopped?
          @vlc.server.start
          sleep @startup # healthy sleep value for VLC to boot
        end

        if @vlc.client.disconnected?
          @vlc.client.connect
          sleep @connect # another healthy sleep value
        end

        @vlc
      end

      module IntentHandlers
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
            _vlc.with_vlc do |vlc|
              vlc.clear
              vlc.play @app.root.abs_path(movies.first.relative_path)
              vlc.fullscreen if _vlc.should_fullscreen?
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
            # if the initial query contained no season/episode data, default to earliest spisode
            sensible_num = query.include?(:episode_num) ? episode.episode_num : 1

            # we have a well-formatted episode (with season data) on our hands
            # build a playlist of the following episodes in the season
            season = Teevee::Library::Episode.where(
                :show => episode.show,
                :season => episode.season
            ).where{episode_num > sensible_num} .order(:episode_num).to_a

            playlist = season.map{ |f| @app.root.abs_path f.relative_path }

            _vlc.with_vlc do |vlc|
              vlc.clear # clear pkaylist
              playlist.each{|f| vlc.add_to_playlist(f) }
              vlc.play
              vlc.fullscreen if _vlc.should_fullscreen?
            end

            return season
          end # end could get season

          _vlc.with_vlc do |vlc|
            vlc.play @app.root.abs_path(episode.relative_path)
            vlc.fullscreen if _vlc.should_fullscreen?
          end

          episode
        end # query_episode

        private

        # retrieves this app's instance of the VLC plugin
        # I wish there was a stronger way to do this
        def _vlc
          plugins.of_type Teevee::Plugins::PlayVideosWithVLC
        end

      end

    end
  end
end
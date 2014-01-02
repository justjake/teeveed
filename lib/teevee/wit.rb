require 'faraday'
require 'json'

module Teevee
  # Provides an API connection to Wit.ai
  # Wit performs all our natural language processing tasks

  module Wit
    # A Wit entity.
    # TODO: is this needed?
    class Entity
      attr_reader :type,      # sym
                  :start,     # int
                  :end,       # int
                  :value,     # any!
                  :body,      # string
                  :suggested  # bool

      def initialize(type, json_hash)
        @type = type.to_sym
        @start = json_hash["start"]
        @end = json_hash["end"]
        @value = json_hash["value"]
        @body = json_hash["body"]
        @suggested = json_hash["suggested"]
      end
    end

    # A specific Wit intent.
    # TODO: is this needed?
    class Intent
      attr_reader :type,        # sym
                  :confidence,  # float
                  :entities     # Hash<EntityType(Sym), Entity>

      def initialize(json_hash)
        @type = json_hash["intent"].to_sym
        @confidence = json_hash["confidence"]
        @entities = {}
        json_hash["entities"].each do |k, v|
          ent = Entity.new(k, v)
          @entities[ent.type] = ent
        end
      end
    end

    # A response to an API query
    class Query
      attr_reader :body
      attr_reader :outcome

      def initialize(json_hash)
        @body = json_hash["msg_body"]
        @outcome = Intent.new(json_hash["outcome"])
      end
    end

    class API < Faraday::Connection
      # Create a new Wit api with the given Oauth access token, as seen
      # at https://console.wit.ai/#/settings
      def initialize(token)
        super('https://api.wit.ai', :headers => {
            'Authorization' => "Bearer #{token}"
        })
      end

      def message(query)
        resp = self.get('/message', :q => query)
        resp.body
      end

      # Send user input data to Wit.ai to recieve a parsed intent
      # should be using Faraday middleware but its inexplicably broken
      # and i'm tired of fighting this problem here
      def message_hash(query)
        JSON.parse(message(query))
      end

      # Fully wrapped and hopefully fixture-safe for future subclassing
      def query(query)
        Query.new(message_hash(query))
      end
    end

  end
end

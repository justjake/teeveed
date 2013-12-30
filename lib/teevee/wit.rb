require 'faraday'
require 'json'

module Teevee
  # Provides an API connection to Wit.ai
  # Wit performs all our natural language processing tasks
  class Wit < Faraday::Connection

    # A specific Wit intent.
    # TODO: is this needed?
    class Intent
      attr_accessor :type     # string
      attr_accessor :entities # Array<Entity>
    end

    # A Wit entity.
    # TODO: is this needed?
    class Entity
      attr_accessor :intent # Intent
      attr_accessor :type   # string
    end

    # Create a new Wit api with the given Oauth access token, as seen
    # at https://console.wit.ai/#/settings
    def initialize(token)
      super('https://api.wit.ai', :headers => {
          'Authorization' => "Bearer #{token}"
      })
    end

    # Send user input data to Wit.ai to recieve a parsed intent
    # should be using Faraday middleware but its inexplicably broken
    # and i'm tired of fighting this problem here
    def message(query)
      resp = self.get('/message', :q => query)
      JSON.parse(resp.body)
    end
  end
end

module Teevee

  # mixin. include to add Postgres full-text search support to a
  # DataMapper resource
  # from https://gist.github.com/BrianTheCoder/217158
  # TODO add postgres trigram support, see http://bartlettpublishing.com/site/bartpub/blog/3/entry/350
  module Searchable
    # run when `include Database::Searchable`
    def self.included(by_class)
      by_class.extend(ClassMethods)
      by_class.instance_eval do
        class_attribute(:search_indexes)
        self.search_indexes = []
      end
    end # included

    module ClassMethods

      # all classes that inherit from this class, directly or indirectly
      def descendants
        ObjectSpace.each_object(Class).select{|k| k < self}
      end

      # crawl up the parent tree and get all the unique
      # search indexes
      def all_search_indexes
        # furthest parent with search indexes
        ancestor = self.ancestors.reverse.find{|a| a.respond_to? :search_indexes}

        # all classes that may define search indexes in this table
        classes = [ancestor] + ancestor.descendants

        # all the properties with search indexes in this table
        classes.map{|c| c.search_indexes}.flatten.uniq
      end

      def search_all(query, options = {})
        search(query, options.merge(:search_indexes => all_search_indexes))
      end

      # perform a full text search
      # @param [String] query     the search terms
      # @param [Hash] options
      # @param [Array<Symbol>] options[:search_indexes] which fields to search
      def search(query, options = {})
        given_search_indexes = options.delete(:search_indexes) || all_search_indexes
        conds = given_search_indexes.map do |index|
          "#{index}_search_index @@ plainto_tsquery(?)"
        end
        conds_array = [conds.join(' OR ')]
        given_search_indexes.size.times { conds_array << escape_string(query) }
        all(options.merge(:conditions => conds_array))
      end

      private

      # escape a string for postgres
      # TODO: replace with DataMapper's DataObject adapeter's escape method
      def escape_string(str)
        str.gsub(/([\0\n\r\032\'\"\\])/) do
          case $1
            when "\0" then "\\0"
            when "\n" then "\\n"
            when "\r" then "\\r"
            when "\032" then "\\Z"
            when "'" then "''"
            else "\\"+$1
          end
        end
      end # escape_string

    end # ClassMethods
  end # Searchable

end # Teevee

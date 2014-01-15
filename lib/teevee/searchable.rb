# -*- encoding : utf-8 -*-
module Teevee

  # Sequel model plugin. include to add Postgres full-text search support to a
  # model plugin spec: http://sequel.jeremyevans.net/rdoc/files/doc/model_plugins_rdoc.html
  # TODO add postgres trigram support, see http://bartlettpublishing.com/site/bartpub/blog/3/entry/350
  # TODO dataset methods
  module Searchable
    # run when `include Database::Searchable`

    module DatasetMethods
      # match a column based on trigram similarity, and order by descending similarity
      # @param column [Symbol] column to match agains
      # @param search [String] search text
      # @param threshold [Float] only results more similar than the threshold will be returned
      def similar(column, search, threshold = 0.3)
        similarity = Sequel.function(:similarity, column, search)
        self.where(similarity > threshold).order_append(similarity.desc)
      end

      # match a column based on trigram similarity, and order by descending similarity
      # an OR method instead of an AND
      # @param column [Symbol] column to match agains
      # @param search [String] search text
      # @param threshold [Float] only results more similar than the threshold will be returned
      def or_similar(column, search, threshold = 0.3)
        similarity = Sequel.function(:similarity, column, search)
        self.or(similarity > threshold).order_append(similarity.desc)
      end

      # perform a full text search
      # @param [Symbol] column   column to search. Must have an index column column_search_index.
      # @param [String] search   the search terms
      def text_match(column, search)
        column = "#{column.to_s}_search_index".to_sym
        self.where(':column @@ plainto_tsquery(:search)', :column => column, :search => search)
          .order_append(Sequel.function(:ts_rank, column, Sequel.function(:plainto_tsquery, search)).desc)
      end

      # perform a full text search
      # an OR method instead of an AND
      # @param [Symbol] column   column to search. Must have an index column column_search_index.
      # @param [String] search   the search terms
      def or_text_match(column, search)
        column = "#{column.to_s}_search_index".to_sym
        self.or(':column @@ plainto_tsquery(:search)', :column => column, :search => search)
          .order_append(Sequel.function(:ts_rank, column, Sequel.function(:plainto_tsquery, search)).desc)
      end
    end # DatasetMethods

    module ClassMethods
      [:similar, :or_similar, :text_match, :or_text_match].each do |meth|
        Sequel::Plugins.def_dataset_methods(self, meth)
      end
    end # ClassMethods

  end # Searchable

end # Teevee

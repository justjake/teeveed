require 'data_mapper'

require 'teevee/library/media'

module Teevee

  # simple SQL generators to add or remove a full-text index
  module Migrations

    TABLE_NAME = 'teevee_library_media'

    # workaround for https://github.com/datamapper/dm-migrations/issues/30
    # which prevents DataMapper.auto_* methods from being using inside migration's eval stuff
    class FakeMigration
      attr_accessor :up, :down,
                    :position,
                    :name,
                    :repository
      def initialize(position, name)
        @position = position
        @name = name
      end
      def perform_up
        up.call
      end
      def perform_down
        down.call
      end

      def say_with_time(message, indent = 2)
        say(message, indent)
        result = nil
        time = Benchmark.measure { result = yield }
        say("-> %.4fs" % time.real, indent)
        result
      end
    end


    # workaround for https://github.com/datamapper/dm-migrations/issues/30
    # which prevents DataMapper.auto_* methods from being using inside migration's eval stuff
    class Migration < DataMapper::Migration
      def setup!
        @adapter = DataMapper.repository(@repository).adapter
      end
    end

    def self.add_text_indexing_seperate(table_name, prop_name)
      table_name = table_name.to_s
      prop_name = prop_name.to_s

      col_name = prop_name + "_search_index"

      return [
        "ALTER TABLE #{table_name} ADD COLUMN #{col_name} tsvector;",
        "UPDATE #{table_name} SET #{col_name} = to_tsvector('english', coalesce(#{prop_name},''));",
        "CREATE TRIGGER #{prop_name}_index_update BEFORE INSERT OR UPDATE ON #{table_name}
            FOR EACH ROW EXECUTE PROCEDURE
            tsvector_update_trigger(#{col_name}, 'pg_catalog.english', #{prop_name});"
      ]
    end

    # postgres commands to add a full-text-search index to a
    # tabel
    # @return [String]
    def self.add_text_indexing(table_name, prop_name)
      add_text_indexing_seperate.join("\n")
    end # add_text_indexing

    def self.remove_text_indexing_seperate(table_name, prop_name)
      return [
        "ALTER TABLE #{table_name} DROP COLUMN #{prop_name}_search_index;",
        "DROP TRIGGER #{prop_name}_index_update ON #{table_name}"
      ]
    end

    # generate an ordered list of DataMapper migrations for the default sections
    # of Media
    # @param media_classes [Array<CLass>] top-level classes that include Searchable
    def self.generate(*media_classes)
      migrations = []

      # automatic migration for EVERYTHING
      # uses private methods, but... ez
      # auto = FakeMigration.new(1, :automatic)
      # auto.up = Proc.new { DataMapper.send(:auto_migrate_up!) }
      # auto.down = Proc.new { DataMapper.send(:auto_migrate_down!) }
      auto = Migration.new(1, :automatic) {}
      auto.up { DataMapper.send(:auto_migrate_up!) }
      auto.down { DataMapper.send(:auto_migrate_down!) }
      migrations << auto

      # find all the properties that should have full-text
      # indexes on all subclasses of Media
      media_classes.each do |klass|
        cols = klass.all_search_indexes
        indexes = Migration.new 2, :search_indexes do
          up do
            cols.each do |col_name|
              sql = Teevee::Migrations.add_text_indexing_seperate(TABLE_NAME, col_name)
              sql.each {|line| adapter.execute(line)}
              # adapter.execute(sql)
            end
          end #up

          down do
            cols.each do |col_name|
              sql = Teevee::Migrations.remove_text_indexing_seperate(TABLE_NAME, col_name)
              sql.each {|line| adapter.execute(line)}
            end
          end # down
        end #indexes
        migrations << indexes
      end

      migrations
    end # generate
  end # migrations
end # Teevee
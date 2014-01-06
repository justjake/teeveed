require 'data_mapper'

module Teevee

  # simple SQL generators to add or remove a full-text index
  module Migrations
    # postgres commands to add a full-text-search index to a
    # tabel
    # @return [String]
    def add_text_indexing(table_name, prop_name)
      table_name = table_name.to_s
      prop_name = prop_name.to_s

      col_name = prop_name + "_search_index"

      return <<-EOF
        ALTER TABLE #{table_name} ADD COLUMN #{col_name} tsvector;
        UPDATE #{table_name} SET #{col_name} = to_tsvector('english', coalesce(#{prop_name},''));
        CREATE TRIGGER #{table_name}_#{prop_name}_index_update BEFORE INSERT OR UPDATE ON #{table_name}
            FOR EACH ROW EXECUTE PROCEDURE
            tsvector_update_trigger(#{col_name}, 'pg_catalog.english', #{prop_name});
      EOF
    end # add_text_indexing

    def remove_text_indexing(table_name, prop_name)
      return <<-EOF
        ALTER TABLE #{table_name} DROP COLUMN #{prop_name}_search_index;
        DROP TRIGGER #{table_name}_#{prop_name}_index_update;
      EOF
    end

    # generate an ordered list of DataMapper migrations for the default sections
    # of Media
    def generate
      migrations = []

      # automatic migration for EVERYTHING
      # uses private methods, but... ez
      auto = DataMapper::Migration.new 1, :automatic do
        up do
          DataMapper.send(:auto_migrate_up!)
        end

        down do
          DataMapper.send(:auto_migrate_down!)
        end
      end #a uto
      migrations << auto

      # find all the properties that should have full-text
      # indexes on all subclasses of Media
      cols = Library::Media.all_search_indexes

      indexes = DataMapper::Migration.new 2, :search_indexes do
        up do
          cols.each do |col_name|
            sql = add_text_indexing('media', col_name)
            repository.adapter.execute(sql)
          end
        end #up

        down do
          cols.each do |col_name|
            sql = remove_text_indexing('media', col_name)
            repository.adapter.execute(sql)
          end
        end # down
      end #indexes
      migrations << indexes

      migrations
    end # generate
  end # migrations
end # Teevee
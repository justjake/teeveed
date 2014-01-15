module Helpers
  # @ return [Array<String>] commands to run
  def add_text_indexing(table_name, prop_name)
    table_name = table_name.to_s
    prop_name = prop_name.to_s

    col_name = prop_name + "_search_index"

    return [
        "ALTER TABLE #{table_name} ADD COLUMN #{col_name} tsvector",
        "UPDATE #{table_name} SET #{col_name} = to_tsvector('english', coalesce(#{prop_name},''))",
        "CREATE TRIGGER #{prop_name}_index_update BEFORE INSERT OR UPDATE ON #{table_name}
              FOR EACH ROW EXECUTE PROCEDURE
              tsvector_update_trigger(#{col_name}, 'pg_catalog.english', #{prop_name})"
    ]
  end

  # postgres commands to add a full-text-search index to a
  # table
  # @return [Array<String>] commands to run
  def remove_text_indexing(table_name, prop_name)
    return [
        "ALTER TABLE #{table_name} DROP COLUMN #{prop_name}_search_index",
        "DROP TRIGGER #{prop_name}_index_update ON #{table_name}"
    ]
  end

  def full_text_columns
    %w(relative_path title show grouping)
  end
end

# Put helpers in the DB scope
Sequel::Database.send(:include, Helpers)

Sequel.migration do
  transaction
  up do
    full_text_columns.each do |col|
      add_text_indexing('media', col)
        .each {|cmd| run(cmd) }
    end
  end

  down do
    full_text_columns.each do |col|
      remove_text_indexing('media', col)
        .each{|cmd| run(cmd)}
    end
  end
end

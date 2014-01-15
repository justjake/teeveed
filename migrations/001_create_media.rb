Sequel.migration do
  change do
    create_table(:media) do
      primary_key   :id
      String        :relative_path, :null => false
      DateTime      :last_seen,     :null => false
      ### Single-table inheritance
      String        :type
      String        :title

      ### Movies
      Integer       :year

      ### Episodes
      String        :show
      String        :grouping
      Integer       :season
      Integer       :episode_num

      index [:relative_path], :name=>:unique_media_relative_path, :unique=>true
    end
  end
end
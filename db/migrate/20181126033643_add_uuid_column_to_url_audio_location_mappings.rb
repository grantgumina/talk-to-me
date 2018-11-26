class AddUuidColumnToUrlAudioLocationMappings < ActiveRecord::Migration[5.2]
  def change
    add_column :url_audio_location_mappings, :uuid, :string
  end
end

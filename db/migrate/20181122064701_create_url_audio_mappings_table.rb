class CreateUrlAudioMappingsTable < ActiveRecord::Migration[5.2]
  def change
    create_table :url_audio_location_mappings do |t|
      t.string :url, null: false
      t.string :audio_location, null: false
      t.timestamps
    end
  end
end

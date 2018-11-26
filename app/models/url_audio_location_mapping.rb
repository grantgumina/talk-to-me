class UrlAudioLocationMapping < ActiveRecord::Base
  # todo - sanitize urls
  validates :url, presence: true
  validates :audio_location, presence: true
  validates :uuid, presence: true

  before_save :downcase_fields

  def downcase_fields
    self.url.downcase
  end

end


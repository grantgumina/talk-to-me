class User < ActiveRecord::Base
  include BCrypt

  # validates :username, presence: true
  # validates :password_hash, presence: true
  before_save :downcase_fields

  def generate_token!
    self.token = SecureRandom.urlsafe_base64(64)
    self.save!
  end

  def password
    @password ||= Password.new(password_hash)
  end

  def password=(password)
    self.password_hash = BCrypt::Password.create(password)
  end

  def downcase_fields
    self.username.downcase
  end

end
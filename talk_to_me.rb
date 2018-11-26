require 'sinatra'
require 'sinatra/json'
require 'sinatra/activerecord'
require 'aws-sdk-polly'
require 'aws-sdk-s3'
require 'pismo'
require 'securerandom'
require 'ruby-sox'
require 'bcrypt'
require 'mailgun-ruby'
require 'rest-client'

# Load up models
require_relative 'app/models/user.rb'
require_relative 'app/models/url_audio_location_mapping.rb'

# Business Logic
class TalkToMe < Sinatra::Base

  configure do
    set :public_folder, 'public'
    set :views, 'app/views'
    enable :sessions
    set :session_secret, "password_security"
    set :database_file, 'config/database.yml'

    # Get Heroku config variables
    set :mailgun_api_key, ENV['MAILGUN_API_KEY']
    set :s3_key, ENV['S3_KEY']
    set :s3_secret, ENV['S3_SECRET']
    set :s3_bucket_name, ENV['S3_BUCKET_NAME']
  end

  before ['/login', '/protected/*'] do
    begin
      if request.body.read(1)
        request.body.rewind
        @request_payload = JSON.parse(request.body.read, { symbolize_names: true })
      end
    rescue JSON::ParserError => e
      request.body.rewind
      puts "The body #{request.body.read} was not JSON"
    end
  end

  before '/protected/*' do
    authenticate!
  end

  def authenticate!
    @user = User.find_by(token: @request_payload[:token])
    halt 403 unless @user
  end

  post '/login' do
    params = @request_payload[:user]
    user = User.find_by(username: params[:username])
    if user.password == params[:password] #compare the hash to the string; magic
      #log the user in and generate a new token
      user.generate_token!

      {token: user.token}.to_json # make sure you give the user the token
    else
      #tell the user they aren't logged in
      "Login unsuccessful"
    end
  end
  
  get '/' do
    json UrlAudioLocationMapping.all
  end

  post '/protected/audio' do

    audio_location = retrieve_audio_location(@request_payload[:url])

    # Return an error if we couldn't get article audio
    audio_halt 200, {error: "Audio couldn't be retrieved"}.to_json unless !audio_location.blank?

    {audio_location: audio_location}.to_json

  end

  post '/request-audio' do
    user_email = params["sender"]
    url = params["subject"]

    # As long as the sender has an authorized email account... yes I know this is hacky
    if !User.find_by(username: user_email).blank?

      # Search for the article in our cache
      url_audio_location_mappings = UrlAudioLocationMapping.select(:uuid).where('url = ?', url)

      if url_audio_location_mappings.empty?
        # If it's not there, generate and store audio
        audio_uuid = generate_audio(url)
      else
        # Otherwise return the cached article location
        audio_uuid = url_audio_location_mappings.first.uuid
      end

      # Download the audio file
      tmp_audio_file_location = "/tmp/#{audio_uuid}.mp3"

      Aws.config.update({
        region: 'us-west-2',
        credentials: Aws::Credentials.new(settings.s3_key, settings.s3_secret)
      })

      s3 = Aws::S3::Resource.new(client: Aws::S3::Client.new(http_wire_trace: true))

      audio_object = s3.bucket(settings.s3_bucket_name).object(audio_uuid)
      audio_object.get(response_target: tmp_audio_file_location)

      # Attach it to an email and send it to the user
      RestClient.post "https://api:#{settings.mailgun_api_key}@api.mailgun.net/v3/grantgumina.com/messages",
        :from => "Talk To Me <mailgun@grantgumina.com>",
        :to => user_email,
        :subject => "Your article audio is ready",
        :text => "Audio file attached",
        :attachment => File.new(File.join("/tmp/", "#{audio_uuid}.mp3"))
    else 
      {message: "You're not a user"}.to_json
    end

  end
  
  def retrieve_audio_location(url)
    url_audio_location_mappings = UrlAudioLocationMapping.select(:audio_location).where('url = ?', url)

    if url_audio_location_mappings.empty?
      audio_uuid = generate_audio(url)
      audio_location = UrlAudioLocationMapping.select(:audio_location).where('uuid = ?', audio_uuid)
    else
      # Otherwise return the cached article location
      audio_location = url_audio_location_mappings.first.audio_location
    end

    # Return an error if we couldn't get article audio
    halt 200, {error: "Audio couldn't be retrieved"}.to_json unless !audio_location.blank?

    return audio_location
  end
  
  def generate_audio(url)
    uuid = SecureRandom.uuid

    # Get audio recording of article
    doc = Pismo::Document.new(url)

    # Leave function if Pismo wasn't able to get article body
    if doc.body.blank?
      return nil
    end
    
    # Break up the document body into 3000 character chunks, but don't cutoff words
    text_array = doc.body.scan(/.{1,3000}\W|.{1,3000}/).map(&:strip)
  
    polly = Aws::Polly::Client.new
  
    file_locations = []
  
    # Get MP3s for each chunk of characters
    text_array.each_with_index do |text, index|
      
      resp = polly.synthesize_speech({
        output_format: "mp3",
        text: text,
        voice_id: "Matthew",
      })
      
      mp3_file_location = "/tmp/article_#{uuid}_#{index}_.mp3"
  
      IO.copy_stream(resp.audio_stream, mp3_file_location)
      file_locations.push(mp3_file_location)
  
      # just to save some money during testing
      # if index == 1
      #   break
      # end

    end
    
    # Check to see that the files have actually been created
    if !file_locations.empty?
  
      output_file_location = "/tmp/ttm_#{uuid}.mp3"

      # Stitch together all the MP3s we get from Polly
      combiner = Sox::Combiner.new(file_locations, :combine => :concatenate)
  
      # Save audio in storage
      combiner.write(output_file_location)

      Aws.config.update({
        region: 'us-west-2',
        credentials: Aws::Credentials.new(settings.s3_key, settings.s3_secret)
      })

    s3 = Aws::S3::Resource.new(client: Aws::S3::Client.new(http_wire_trace: true))

      article_mp3_object = s3.bucket(settings.s3_bucket_name).object(uuid)
      article_mp3_object.upload_file(output_file_location)

      article_mp3_object_url = article_mp3_object.public_url
      
      # Create DB entry for audio/URL
      UrlAudioLocationMapping.create(url: url, audio_location: article_mp3_object_url, uuid: uuid)
      
      # Return uuid of audio object
      return uuid
    end
  end

end
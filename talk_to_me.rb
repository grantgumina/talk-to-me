require 'sinatra'
require 'sinatra/json'
require 'sinatra/activerecord'
require 'aws-sdk-polly'
require 'pismo'
require 'securerandom'
require 'ruby-sox'
require 'bcrypt'

set :database_file, 'config/database.yml'

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
  end

  before do
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

  def generate_audio(url)
    uuid = SecureRandom.uuid

    # Get audio recording of article
    doc = Pismo::Document.new(url)
    
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
      puts "#{mp3_file_location}"
      file_locations.push(mp3_file_location)
  
      # just to save some money during testing
      if index == 1
        break
      end
    end
    
    if !file_locations.empty?
  
      output_file_location = "audio/ttm_#{uuid}.mp3"
  
      # Stitch together all the MP3s we get from Polly
      combiner = Sox::Combiner.new(file_locations, :combine => :concatenate)
  
      # Save audio in storage
      combiner.write(output_file_location)

      # Create DB entry for audio/URL
      UrlAudioLocationMapping.create(url: url, audio_location: output_file_location)
      
      # Send user the mp3
      return output_file_location
    end
  end

  post '/audio' do
    authenticate!

    url = @request_payload[:url]
    url_mp3_location = ""
  
    # Lookup if article has been audioized before
    url_audio_location_mappings = UrlAudioLocationMapping.select(:audio_location).where('url = ?', url)

    if !url_audio_location_mappings.empty?
      # check to see if file exists before sending it...
      if (File.exist?(url_audio_location_mappings.first.audio_location))
        url_mp3_location = url_audio_location_mappings.first.audio_location
      else
        url_mp3_location = generate_audio(url)
      end
    else
      url_mp3_location = generate_audio(url)
    end

    send_file(url_mp3_location)

  end
end
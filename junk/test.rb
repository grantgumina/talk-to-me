require 'aws-sdk-polly'
require 'pismo'
require 'ruby-sox'

if ARGV.empty?()
  puts 'You must supply a url'
  exit 1
end

user_url = ARGV[0]

doc = Pismo::Document.new(user_url)

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
    
  mp3_file_location = "audio/article_#{index}_.mp3"

  IO.copy_stream(resp.audio_stream, mp3_file_location)
  puts "#{mp3_file_location}"
  file_locations.push(mp3_file_location)

  if index == 2
    break
  end
end

# Stitch together all the MP3s we get from Polly
if !file_locations.empty?
  combiner = Sox::Combiner.new(file_locations, :combine => :concatenate)
  combiner.write('out.mp3')
end

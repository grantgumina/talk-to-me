require 'aws-sdk-polly'
require 'pismo'


if ARGV.empty?()
  puts 'You must supply a url'
  exit 1
end

user_url = ARGV[0]

doc = Pismo::Document.new(user_url)

polly = Aws::Polly::Client.new

resp = polly.synthesize_speech({
  output_format: "mp3",
  text: doc.body,
  voice_id: "Joanna",
})

name = File.basename('url_audio')
parts = name.split('.')
first_part = parts[0]
mp3_file = first_part + '.mp3'

IO.copy_stream(resp.audio_stream, mp3_file)
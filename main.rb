require 'sinatra'
require 'aws-sdk-polly'

get '/' do
  polly = Aws::Polly::Client.new

  resp = polly.synthesize_speech({
    output_format: "mp3",
    text: contents,
    voice_id: "Joanna",
  })

end


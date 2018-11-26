require 'aws-sdk-s3'
require 'securerandom'

uuid = SecureRandom.uuid

Aws.config.update({
  region: 'us-west-2',
  credentials: Aws::Credentials.new('AKIAIT32RJ3GQYMMAK3Q', 'uezj5J3lhZWhMtiREK8Sntd82WrXp+1C3TplJkoF')
})

s3 = Aws::S3::Resource.new(client: Aws::S3::Client.new(http_wire_trace: true))

bucket_name = 'talk-to-me-grantgumina'

article_mp3_object = s3.bucket(bucket_name).object(uuid)
article_mp3_object.upload_file('/Users/ggumina/Desktop/test.mp3')


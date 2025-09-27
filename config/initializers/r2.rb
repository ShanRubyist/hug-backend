require 'aws-sdk-s3'

R2_CLIENT = Aws::S3::Client.new(
  endpoint: ENV.fetch('R2_ENDPOINT'),
  access_key_id: ENV.fetch('R2_ACCESS_KEY_ID'),
  secret_access_key: ENV.fetch('R2_SECRET_ACCESS_KEY'),
  region: 'auto', # R2 要求 region 设为 auto
  # bucket: ENV.fetch('R2_BUCKET'),
  # request_checksum_calculation: "when_required",
  # response_checksum_validation: "when_required"
)

R2_PRESIGNER = Aws::S3::Presigner.new(client: R2_CLIENT)

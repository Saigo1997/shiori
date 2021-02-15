# frozen_string_literal: true

if Rails.env.production?
  CarrierWave.configure do |config|
    config.storage :fog
    config.fog_provider = 'fog/aws'
    config.fog_credentials = {
      # Amazon S3用の設定
      provider: 'AWS',
      region: ENV['S3_REGION'],
      host: ENV['S3_HOST'],
      aws_access_key_id: ENV['S3_ACCESS_KEY'],
      aws_secret_access_key: ENV['S3_SECRET_KEY'],
      path_style: true
    }
    config.fog_directory = ENV['S3_BUCKET']
  end
end

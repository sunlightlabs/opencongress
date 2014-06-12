CarrierWave.configure do |config|
  CarrierWave::SanitizedFile.sanitize_regexp = /[^[:word:]\.]/

  config.root = Rails.root.join('tmp')
  config.cache_dir = 'carrierwave'
  config.fog_credentials = {
    :provider => 'AWS',
    :aws_access_key_id => ApiKeys.aws_access_key_id,
    :aws_secret_access_key =>  ApiKeys.aws_secret_access_key,

    # Note: S3 uploads into "uploads" dir on the host.
  }

  config.fog_directory = "a4.opencongress.org"
end

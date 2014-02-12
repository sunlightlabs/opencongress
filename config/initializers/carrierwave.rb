CarrierWave.configure do |config|
  CarrierWave::SanitizedFile.sanitize_regexp = /[^[:word:]\.]/

  config.root = Rails.root.join('tmp')
  config.cache_dir = 'carrierwave'
  config.fog_credentials = {
    :aws_access_key_id => ApiKeys.aws_access_key_id,
    :aws_secret_access_key =>  ApiKeys.aws_secret_access_key,
    'config.s3_bucket' => "a4.opencongress.org"
    # Note: S3 uploads into "uploads" dir on the host.
  }

end

# Contains configuration for Geocoder from variables set in config/api_keys.yml
Geocoder.configure(
  # :use_https => true,
  :lookup => :smarty_streets,
  :timeout => 30.seconds,

  :mapquest => {
    :licensed => true,
    :api_key => ApiKeys.mapquest
  },

  :smarty_streets => {
    :api_key => [ApiKeys.smarty_streets_id, ApiKeys.smarty_streets_token]
  },

  :texas_am => {
    :api_key => ApiKeys.texas_am_api_key,
    :version => '4.01',
    :format_forward => 'XML',
    :format_reverse => 'JSON'
  }

  # No API Keys for :geocoder_ca or :esri
)
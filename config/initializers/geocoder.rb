Geocoder.configure(
  # :use_https => true,
  :lookup => :smarty_streets,

  :mapquest => {
    :licensed => true,
    :api_key => ApiKeys.mapquest
  },

  :smarty_streets => {
    :api_key => [ApiKeys.smarty_streets_id, ApiKeys.smarty_streets_token]
  }

  # No API Keys for :geocoder_ca or :esri
)
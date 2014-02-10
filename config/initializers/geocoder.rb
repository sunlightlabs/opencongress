Geocoder.configure(
  :use_https => true,
  :lookup => :mapquest,

  :mapquest => {
    :licensed => true,
    :api_key => ApiKeys.mapquest
  }
)
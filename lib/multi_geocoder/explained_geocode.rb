require_dependency 'geocoder'

module MultiGeocoder
  class ExplainedGeocode
    def initialize(data)
      @data = data
    end

    def query_type
      return @data[:query_type]
    end

    def is_zip5?
      return query_type == :zip5
    end

    def is_zip9?
      return query_type == :zip9
    end

    def is_city_state?
      return query_type == :city_state
    end

    def is_street_only?
      return query_type == :street_only
    end

    def is_full_address?
      return query_type == :full_address
    end

    def lookup
      return @data[:lookup] || Geocoder.config.lookup
    end

    def query_state
      if [:city_state, :street_only, :full_address].include? query_type
        return @data[:query].scan(/\b([A-Za-z]{2})\b/).last.first
      end
    rescue
      nil
    end

    def contains_state?
      !!query_state
    end

    def query_zip5
      return @data[:query].scan(/\b.+([0-9]{5})\b/).last.first
    rescue NoMethodError
      nil
    end

    def contains_zip?
      !!query_zip5
    end

    def query_zip4
      return @data[:query].scan(/\b.+-([0-9]{4})\b/).last.first
    rescue NoMethodError
      nil
    end

    def contains_zip4?
      !!query_zip4
    end

    def query_zip9
      return @data[:query].scan(/\b.+([0-9]{5}-[0-9]{4})\b/).last.first
    rescue
      nil
    end
  end
end

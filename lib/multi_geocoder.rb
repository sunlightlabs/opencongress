require 'geocoder'
require 'multi_geocoder/explained_geocode'

##
# This module checks the incoming query and decides which geocoder to dispatch
# to depending on what it sees. Smarty Streets is a free unlimited account so we
# prefer it where possible, but it won't code partial addresses or zip+4s.
# In those cases we pass off to ESRI which doesn't require authentication.
#
module MultiGeocoder
  ZIP_PATTERN = /\A[\d]{5}\Z/
  ZIP_PLUS_PATTERN = /\A[\d]{5}-?[\d]{4}\Z/
  CITY_STATE_AND_ZIP_PATTERN = /\A[A-Z][a-zA-Z\-, ]+ [\d\-]{5,10}\Z/
  CITY_STATE_ONLY_PATTERN = /\A[A-Z][a-zA-Z\-, ]+ ?(?:[\d\-]{5,10})?\Z/
  STREET_ONLY_PATTERN = /\A[\d]{0,3}[a-zA-Z\-]+.*\Z/
  USPS_STATE_PATTERN = /\b[A-Z]{2}\b/
  AP_STATE_PATTERN = /\b[ACDFGHIKLMNOPRSTUVW].?[A-Za-z.]{2,5}\b/


  def self.explain(query, opts=nil)
    query, opts = prepare(query, opts)
    type = query_type(query)
    ExplainedGeocode.new(opts.merge({ :query => query, :query_type => type }))
  end

  def self.search(query, opts=nil)
    Geocoder.search(*prepare(query, opts))
  end

  def self.coordinates(query, opts=nil)
    Geocoder.coordinates(*prepare(query, opts))
  end

  def self.reverse(query, opts=nil)
    opts ||= {:lookup => :esri}
    Geocoder.search(query, opts)
  end

  ## helper methods below

  def self.query_type(query)
    query_type = nil
    if query =~ ZIP_PATTERN
      query_type = :zip5
    elsif query =~ ZIP_PLUS_PATTERN
      query_type = :zip9
    elsif query =~ CITY_STATE_AND_ZIP_PATTERN
      query_type = :city_state_zip
    elsif query =~ CITY_STATE_ONLY_PATTERN
      query_type = :city_state
    elsif query =~ STREET_ONLY_PATTERN
      query_type = :street_only
    else
      if query =~ USPS_STATE_PATTERN || query =~ AP_STATE_PATTERN
        query_type = :full_address
      else
        query_type = :partial_address
      end
    end
    query_type
  end

  def self.prepare(query, opts=nil)
    opts ||= {}
    # Awful kludge to remove country from query
    query = query.chomp('USA')
                 .chomp('US')
                 .strip()
                 .chomp(',')
    type = query_type(query)

    # For all of the cases where smartystreets fails,
    # use ESRI instead. The latter will not return a zip4.
    if [:zip9, :city_state, :street_only].include? type
      opts[:lookup] ||= :esri
      query = "#{query} USA"
    end

    # Geocoder.ca does a better job with city/state/zip than ESRI,
    # Solves The Clarksville / Fort Campbell problem.
    if type == :city_state_zip
      opts[:lookup] ||= :geocoder_ca
      query = "#{query} USA"
    end

    [query, opts]
  end
end

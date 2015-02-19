# == Schema Information
#
# Table name: searches
#
#  id                :integer          not null, primary key
#  search_text       :string(255)
#  created_at        :datetime
#  search_filters    :text
#  page              :integer
#  user_id           :integer
#  search_congresses :text
#

class Search < OpenCongressModel

  #========== INCLUDES

  include SearchHelper
  include ActionView::Helpers::TextHelper
  include Elasticsearch::Model

  #========== CONSTANTS

  SEARCHABLE_INDICES_WITH_BOOSTS = {
    :bills => 100,
    :committees => 25,
    :people => 10,
    :subjects =>  0.1
  }

  SEARCHABLE_INDICES = SEARCHABLE_INDICES_WITH_BOOSTS.collect{|k,v| k.to_s }

  DEFAULT_SEARCH_SIZE = Settings.default_search_size rescue 100

  SEARCH_FILTERS = [:bills, :people, :committees, :industries, :issues, :news, :blogs,
                    :commentary, :comments, :gossip_blog]

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :user

  #========== CALLBACKS

  before_validation :doctor_data_for_save
  after_save :doctor_data_for_load
  after_find :doctor_data_for_load

  #========== VALIDATORS

  validates :page, numericality: { greater_than: 0 }, allow_blank: true
  validates :search_text, length: { minimum: 4, message: 'Your query must be longer than three characters!'}
  validates :search_text, length: { maximum: 255, message: 'Your query is too long (>255 characters)!'}
  validates :search_text, presence: {message: "You didn't enter anything meaningful into the search field!"}
  validates :search_filters, array_member: { in: SEARCH_FILTERS }


  #========== SERIALIZERS

  serialize :search_filters, Array
  serialize :search_congresses, Array

  #========== METHODS

  #----- CLASS

  # Prepends search filters with 'search_' to namespace
  # them in other scopes.
  #
  # @param filters [Array<Symbol>] defaults to constant defined in Search
  # @param to_sym [Boolean] true to also convert to symbols, false otherwise
  # @return [Array<String>, Array<Symbol>] array of filters prepended by 'search_'
  def self.search_filter_prepend(filters = SEARCH_FILTERS, to_sym = false)
    filters.map {|f| eval("f.to_s.prepend('search_')#{'.to_sym' if to_sym}") }
  end

  # Adds the namespacing 'search_' to filter list
  #
  # @param filters [Array<String>]
  # @param to_sym [Boolean] true to also convert to symbols, false otherwise
  # @return [Array<String>, Array<Symbol>] array of filters with namespace 'search_' removed
  def self.search_filter_trim(filters, to_sym = false)
    filters.map {|f| eval("f.gsub('search_', '')#{'.to_sym' if to_sym}") }
  end

  def self.search_filter_list
    search_filter_prepend(SEARCH_FILTERS)
  end

  # Drops all indices from elasticsearch and creates them again.
  # USE TO RESET INDICES AND RELOAD DATA
  def self.reset_all_indices
    create_all_indices and import_all_indices
  end

  # Drops all indices in elasticsearch for searchable models
  def self.drop_all_indices
    SEARCHABLE_INDICES.each {|name| name.singularize.camelize.constantize.drop_index }
  end

  # Creates indices, forcing new settings
  def self.create_all_indices
    SEARCHABLE_INDICES.each {|name| name.singularize.camelize.constantize.create_index }
  end

  # Creates all indices in elasticsearch for searchable models
  def self.import_all_indices
    SEARCHABLE_INDICES.each {|name| name.singularize.camelize.constantize.import_bulk }
  end

  # Performs search on searchable models using elasticsearch
  #
  # @param query [String] what to search for in database
  # @param indices [String] indices to limit search to
  # @param limit [Integer] limit on records returned
  # @return [Relation<SearchableObject>] found records
  def self.search(query, indices = SEARCHABLE_INDICES, limit = DEFAULT_SEARCH_SIZE)
    prepare_search(query,indices,limit).hits.hits.collect{|record| record._type.camelize.constantize.find(record._id) }
  end

  # Prepares and submits search to elasticsearch
  #
  # @param query [String] what to search for in database
  # @param indices [String] indices to limit search to
  # @param limit [Integer] limit on records returned
  # @return [Hash] hash of elasticsearch return
  def self.prepare_search(query, indices = SEARCHABLE_INDICES, limit = DEFAULT_SEARCH_SIZE)
    # doctor text for elasticsearch
    query = prepare_elasticsearch_text(query)
    # check to see if user is searching for specific index, i.e. "healthcare bills"
    final_indices = []
    indices.each {|i| final_indices.push(i) if query.include?(i.to_s) }
    if final_indices.any?
      indices = final_indices
      indices.each {|i| query.gsub!(Regexp.new("(#{i.to_s})|(#{i.to_s.singularize})"),'') }
    end
    # construct search queries and initiate search
    search_queries = indices.collect{|i| i.singularize.camelize.constantize.search_query(query)}
    query = {body: elasticsearch_body(search_queries, limit)}
    query[:index] = indices if indices.any?
    Elasticsearch::Model.client.search(query)
  end

  def self.prepare_elasticsearch_text(query)
    # we only want lowercase
    # query.downcase!
    # remove additional spaces
    query.strip!
    # remove non alphanumeric
    query.gsub!(/[^\w\.\s\-_]+/, '')
    # replace multiple spaces with one space
    query.gsub!(/\s+/, ' ')
    query
  end

  # Constructs the hash to pass into elasticsearch
  #
  # @param search_queries [Array<Hash>] what to query for in elasticsearch
  # @return [Hash] hash of full elasticsearch query
  def self.elasticsearch_body(search_queries = [], limit = DEFAULT_SEARCH_SIZE)
    {
      size: limit,
      indices_boost: SEARCHABLE_INDICES_WITH_BOOSTS,
      query: {
        function_score: {
          query: {
            dis_max: {
              queries: search_queries
            }
          },
          functions: [
            {
              field_value_factor: {
                field: 'page_views_count',
                modifier: 'sqrt',
                factor: 1
              }
            },
            {
              field_value_factor: {
                field: 'bookmark_count',
                modifier: 'sqrt',
                factor: 1
              }
            },
          ]
        }
      }
    }
  end

  # Retrieves the top searched terms from the database
  #
  # @return [Relation<Search>] top searches
  def self.top_search_terms(num = 100, since = Settings.default_count_time)
    Search.find_by_sql(["SELECT LOWER(search_text) as text, COUNT(id) as count
                         FROM searches
                         WHERE created_at > ? AND LOWER(search_text) <> 'none'
                         GROUP BY LOWER(search_text) ORDER BY count DESC LIMIT ?", since.ago, num])
  end

  #----- INSTANCE

  public

  # Convenience method to get congresses from the search filters.
  #
  # @return [Array<String>] the congresses numbers as strings
  def get_congresses
    self.search_congresses
  end

  # Prepare search text for submission as a query to search.
  def get_query_stripped
    prepare_tsearch_query(self.search_text.to_s)
  end

  # Initiate a search
  def initiate_search
    Search.search(self.search_text)
  end

  private

  # Doctors the input data before saving to the database.
  #
  def doctor_data_for_save
    self.page = 1 if (self.page.nil? || self.page < 1)
    self.search_text = truncate(self.search_text, :length => 255)
    self.search_filters = self.class.search_filter_trim(self.search_filters, to_sym = true)
    self.search_congresses = ["#{Settings.default_congress}"] unless self.search_congresses.is_a? Array
  end

  # This is the reverse operation for :doctor_data_for_save whereby
  # we convert the database representation to the explicit symbol
  # representation for each search filter.
  #
  def doctor_data_for_load
    self.search_filters = self.class.search_filter_prepend(self.search_filters)
  end

end
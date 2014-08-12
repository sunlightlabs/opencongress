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

class Search < ActiveRecord::Base

  #========== INCLUDES

  include SearchHelper
  include ActionView::Helpers::TextHelper

  #========== CONSTANTS

  # The search filters that a user selects are stored in the database as a list of integers corresponding to
  # the order by which they appear in this list. This is done to limit extraneous space usage.
  SEARCH_FILTERS_LIST = [
                          :search_bills, :search_people, :search_committees, :search_industries, :search_issues,
                          :search_news, :search_blogs, :search_commentary, :search_comments, :search_gossip_blog
                        ]

  SEARCH_FILTER_CODE_MAP = Hash[SEARCH_FILTERS_LIST.collect.with_index {|v,i| [v,i]}]
  CODE_SEARCH_FILTER_MAP = SEARCH_FILTER_CODE_MAP.invert()

  #========== RELATIONS

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

  #========== SERIALIZERS

  serialize :search_filters, Array
  serialize :search_congresses, Array

  #========== PUBLIC METHODS
  public

  ##
  # Doctors the input data before saving to the database. This is done to compress the search filters
  # into a smaller size so we don't needlessly store extraneous information in the database.
  #
  def doctor_data_for_save
    self.page = 1 if (self.page.nil? || self.page < 1)
    self.search_text = truncate(self.search_text, :length => 255)
    self.search_filters.each_with_index {|v,i|
      self.search_filters[i] = SEARCH_FILTER_CODE_MAP[v.to_sym] if v.is_a? String
    }
    unless self.search_congresses.is_a? Array then self.search_congresses = ["#{Settings.default_congress}"] end
  end

  ##
  # This is the reverse operation for :doctor_data_for_save whereby
  # we convert the database representation to the explicit symbol
  # representation for each search filter.
  #
  def doctor_data_for_load
    if self.search_filters
      self.search_filters.each_with_index {|v,i| self.search_filters[i] = CODE_SEARCH_FILTER_MAP[v] }
    end
    self.search_text = prepare_tsearch_query(self.search_text.to_s)
  end

  ##
  # Convience method to get congresses from the search filters
  #
  def get_congresses
    return self.search_congresses
  end

  ##
  # Retrieves the top searched terms from the database
  #
  def Search.top_search_terms(num = 100, since = Settings.default_count_time)
    Search.find_by_sql(["SELECT LOWER(search_text) as text, COUNT(id) as count 
                         FROM searches 
                         WHERE created_at > ? AND LOWER(search_text) <> 'none'
                         GROUP BY LOWER(search_text) ORDER BY count DESC LIMIT ?", since.ago, num])
  end

end

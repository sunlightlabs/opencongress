# == Schema Information
#
# Table name: searches
#
#  id             :integer          not null, primary key
#  search_text    :string(255)
#  created_at     :datetime
#  search_filters :text
#  page           :integer
#  user_id        :integer
#

class Search < ActiveRecord::Base

  SEARCH_FILTER_CODE_MAP = {
      :bills => 'bi',
      :people => 'pe',
      :committees => 'co',
      :industries => 'in',
      :issues => 'is',

  }

  # TODO: add field to link a user search to user if one exists
  # TODO: add list field for what to search in and sessions
  #========== RELATIONS

  belongs_to :user

  #========== VALIDATORS

  validates_numericality_of :page, greater_than: 0

  #========== SERIALIZERS

  serialize :search_filters, # List serialization

  #========== CALLBACKS

  def Search.top_search_terms(num = 100, since = Settings.default_count_time)
    Search.find_by_sql(["SELECT LOWER(search_text) as text, COUNT(id) as count 
                         FROM searches 
                         WHERE created_at > ? AND LOWER(search_text) <> 'none'
                         GROUP BY LOWER(search_text) ORDER BY count DESC LIMIT ?", since.ago, num])
  end
end

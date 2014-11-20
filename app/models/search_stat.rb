# == Schema Information
#
# Table name: search_stats
#
#  id                    :integer          not null, primary key
#  search_text           :string(255)
#  total_searches        :integer
#  total_avg_per_day     :integer
#  total_unique_users    :integer
#  recent_total_searches :integer
#  recent_avg_per_day    :integer
#  recent_unique_users   :integer
#  created_at            :datetime
#  updated_at            :datetime
#

class SearchStat < OpenCongressModel

end
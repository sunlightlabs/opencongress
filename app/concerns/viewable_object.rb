module ViewableObject
  extend ActiveSupport::Concern

  included do
    has_many :object_aggregates, :as => :aggregatable
  end

  #========== METHODS

  #----- CLASS

  def self.abstract_class?
    true
  end

  #----- INSTANCE

  # Method to call when a page has been viewed
  def page_view
    self.object_aggregates.find_or_create_by(date: Date.today).increment!(:page_views_count)
  end

  # Retrieves the number of pages in input seconds ago
  #
  # @param seconds [Integer] seconds ago to retrieve the number of page counts for
  # @return [Integer] sum of views
  def views(seconds = 0)
    # if the view_count is part of this instance's @attributes use that because it came from
    # the query and will make sense in the context of the page; otherwise, count
    return @attributes['view_count'] if @attributes['view_count']

    if seconds <= 0
      @attributes['page_views_count'].nil? ? object_aggregates.sum(:page_views_count) : @attributes['page_views_count'].to_i
    else
      self.object_aggregates.where('date >= ?', seconds.ago).sum(:page_views_count)
    end
  end

end
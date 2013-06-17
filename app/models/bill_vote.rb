class BillVote < ActiveRecord::Base
  # 1 = opposed, 0 = supported
  belongs_to :user
  belongs_to :bill
  after_save :save_associated_user

  scope :supporting, where(:support => 0)
  scope :opposing, where(:support => 1)

  private
  def save_associated_user
    # removed solr stuff for now -- June 2012
    #self.user.solr_save
  end
end

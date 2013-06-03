class CommitteeName < ActiveRecord::Base
  attr_accessible :name, :session

  belongs_to :committee
end

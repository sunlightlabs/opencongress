# == Schema Information
#
# Table name: refers
#
#  id        :integer          not null, primary key
#  label     :string(255)
#  ref       :string(255)
#  action_id :integer
#

class Refer < ActiveRecord::Base
  validates_uniqueness_of :ref
  belongs_to :action

  def to_s
    self.label.capitalize 
  end
end

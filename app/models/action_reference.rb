# == Schema Information
#
# Table name: action_references
#
#  id        :integer          not null, primary key
#  action_id :integer
#  label     :string(255)
#  ref       :string(255)
#

class ActionReference < OpenCongressModel
  belongs_to :action
end

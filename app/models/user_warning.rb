# == Schema Information
#
# Table name: user_warnings
#
#  id              :integer          not null, primary key
#  user_id         :integer
#  warning_message :text
#  warned_by       :integer
#  created_at      :datetime
#  updated_at      :datetime
#

class UserWarning < ActiveRecord::Base

  belongs_to :user
  belongs_to :admin, :class_name => "User", :foreign_key => :warned_by  

end

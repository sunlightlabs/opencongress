# == Schema Information
#
# Table name: twitter_configs
#
#  id                 :integer          not null, primary key
#  user_id            :integer
#  secret             :string(255)
#  token              :string(255)
#  tracking           :boolean
#  bill_votes         :boolean
#  person_approvals   :boolean
#  new_notebook_items :boolean
#  logins             :boolean
#  created_at         :datetime
#  updated_at         :datetime
#

class TwitterConfig < ActiveRecord::Base
  belongs_to :user
  
  
end

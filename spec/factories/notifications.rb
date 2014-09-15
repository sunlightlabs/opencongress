# == Schema Information
#
# Table name: notifications
#
#  id                    :integer          not null, primary key
#  user_id               :integer
#  notifying_object_id   :integer
#  seen                  :integer
#  created_at            :datetime
#  updated_at            :datetime
#  notifying_object_type :string(255)
#

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :notification do
    user_id 1
    notifying_object 1
    seen 1
  end
end

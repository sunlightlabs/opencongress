# == Schema Information
#
# Table name: actions
#
#  id               :integer          not null, primary key
#  action_type      :string(255)
#  date             :integer
#  datetime         :datetime
#  how              :string(255)
#  where            :string(255)
#  vote_type        :string(255)
#  result           :string(255)
#  bill_id          :integer
#  amendment_id     :integer
#  type             :string(255)
#  text             :text
#  roll_call_id     :integer
#  roll_call_number :integer
#  created_at       :datetime
#  govtrack_order   :integer
#  in_committee     :text
#  in_subcommittee  :text
#  ordinal_position :integer
#

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :first_action , class: Action do
    bill_id "56724"
    date "1238644800"
    id "190904"
    action_type "introduced"
    datetime Time.new(2009, 04, 02, 00, 00, 00)
  end

  factory :second_action , class: Action do 
    bill_id "56724"
    text "Read twice and referred to the Committee on Health, Education, Labor, and Pensions. "
    date "1238644800" 
    type 'BillAction'
    id "190905"
    action_type 'action' 
    datetime Time.new(2009, 04, 02, 00, 00, 00)
  end
end

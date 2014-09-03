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

FactoryGirl.define do
  factory :activity_option do
    key 'bill_action.create'
    owner_model 'Bill'
    trackable_model 'BillAction'    
  end
end
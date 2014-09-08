# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :article do
    tag_list 'foo,bar,baz'
  end
end

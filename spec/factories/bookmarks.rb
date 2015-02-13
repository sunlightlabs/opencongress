FactoryGirl.define do
  factory :bookmark_on_bill, :class => Bookmark do
    bookmarkable_type "Bill"
    bill { FactoryGirl.create(:bill) }
    user
  end
end

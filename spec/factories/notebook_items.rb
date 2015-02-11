FactoryGirl.define do
  factory :notebook_item do
    description "Describe describe describe describe"
    title "Ukraine Says Russian Forces Lead Major New Offensive in East"
    type "NotebookLink"
    updated_at { Time.now }
    url "http://www.nytimes.com/2014/08/28/world/europe/ukraine-russia-novoazovsk-crimea.html"
  end
end
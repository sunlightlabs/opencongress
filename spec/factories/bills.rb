# == Schema Information
#
# Table name: bills
#
#  id                     :integer          not null, primary key
#  session                :integer
#  bill_type              :string(7)
#  number                 :integer
#  introduced             :integer
#  sponsor_id             :integer
#  lastaction             :integer
#  rolls                  :string(255)
#  last_vote_date         :integer
#  last_vote_where        :string(255)
#  last_vote_roll         :integer
#  last_speech            :integer
#  pl                     :string(255)
#  topresident_date       :integer
#  topresident_datetime   :date
#  summary                :text
#  plain_language_summary :text
#  hot_bill_category_id   :integer
#  updated                :datetime
#  page_views_count       :integer
#  is_frontpage_hot       :boolean
#  news_article_count     :integer          default(0)
#  blog_article_count     :integer          default(0)
#  caption                :text
#  key_vote_category_id   :integer
#  is_major               :boolean
#  top_subject_id         :integer
#  short_title            :text
#  popular_title          :text
#  official_title         :text
#  manual_title           :text
#

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :bill do 
    session { Settings.default_congress } 
    bill_type "hr" 
    number { rand(1..2000) }
    introduced 1231218000
    sponsor_id 400350
    lastaction 1234155600 
    rolls nil 
    last_vote_date nil 
    last_vote_where nil 
    last_vote_roll nil 
    last_speech nil 
    pl nil 
    topresident_date 1234159200
    topresident_datetime "2009-02-09"
    summary "Blair Holt's Firearm Licensing and Record of Sale ..."
    plain_language_summary "The Blair Holt's Firearm Licensing and Record of S..." 
    hot_bill_category_id nil 
    updated 30.days.to_i 
    page_views_count 1421649 
    is_frontpage_hot false
    news_article_count 333 
    blog_article_count 4922 
    caption 'Tacos Tacos Tacos Burritos Burritos Burritos' 
    key_vote_category_id nil 
    is_major nil 
    top_subject_id 8580 
    short_title { "The bill's short title #{number}" }
    popular_title nil
    official_title nil
    manual_title nil
  end
end

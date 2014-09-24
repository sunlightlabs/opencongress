# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :bill do
    id 54050 
    session 111 
    bill_type "hr" 
    number 45 
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
    short_title nil 
    popular_title nil 
    official_title nil 
    manual_title nil
  end
end

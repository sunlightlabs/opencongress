FactoryGirl.define do
  factory :person do
    firstname { Faker::Name.first_name }
    middlename nil
    lastname { Faker::Name.last_name }
    nickname "Curt"
    birthday "Mon 28 Sep 1959"
    gender "M"
    religion nil
    url nil
    party "Republican"
    osid nil
    bioguideid {"lastname[0]#{'%06d' % rand(999999)}"} 
    title "Rep."
    state "FL"
    district "19"
    name { "#{firstname} #{lastname}" }
    email nil
    fti_names "'clawson':2,4,7 'curt':5,6 'curti':1,3"
    user_approval 5.0
    biography nil
    unaccented_name "Curt Clawson"
    metavid_id nil
    youtube_id nil
    website nil
    congress_office nil
    phone nil
    fax nil
    contact_webform nil
    watchdog_id nil
    page_views_count 71
    news_article_count 0
    blog_article_count 0
    total_session_votes nil
    votes_democratic_position nil
    votes_republican_position nil
    govtrack_id 412604
    fec_id nil
    thomas_id "02200"
    cspan_id 75516
    lis_id nil
    death_date nil
    twitter_id nil
    factory :senator do 
      after(:create) do |sen, evaluator|
        create_list(:role, 1, {
          :person => sen,
          :state => sen.state,
          :party => sen.party,
          :district => sen.district,
          :startdate => NthCongress.start_datetime(Settings.default_congress),
          :enddate => NthCongress.start_datetime(Settings.default_congress) + 6.years
        })
      end
    end
    factory :staggered_senator do 
      after(:create) do |sen, evaluator|
        create_list(:role, 1, {
          :person => sen,
          :state => sen.state,
          :party => sen.party,
          :district => sen.district,
          :startdate => NthCongress.start_datetime(Settings.default_congress) - 2.years,
          :enddate => NthCongress.start_datetime(Settings.default_congress) + 4.years
        })
      end
    end
    factory :representative do 
      after(:create) do |rep, evaluator|
        create_list(:role, 1, {
          :person => rep,
          :state => rep.state,
          :party => rep.party,
          :district => rep.district
        })
      end
    end
    factory :retired do
      after(:create) do |retired, evaluator|
        create_list(:role, 1, {
          :person => retired,
          :state => retired.state,
          :party => retired.party,
          :district => retired.district,
          :startdate => Date.new(1915,1,3),
          :enddate => Date.new(1917,1,3)
        })
      end
    end
    factory :just_retired do 
      after(:create) do |just_retired, evaluator|
        create_list(:role, 1, {
          :person => just_retired,
          :state => just_retired.state,
          :party => just_retired.party,
          :district => just_retired.district,
          :startdate => NthCongress.start_datetime(Settings.default_congress - 1),
          :enddate => NthCongress.end_datetime(Settings.default_congress - 1)
        })
      end
    end
  end
end
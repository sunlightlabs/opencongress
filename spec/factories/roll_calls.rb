# == Schema Information
#
# Table name: roll_calls
#
#  id                  :integer          not null, primary key
#  number              :integer
#  where               :string(255)
#  date                :datetime
#  updated             :datetime
#  roll_type           :text
#  question            :text
#  required            :string(255)
#  result              :string(255)
#  bill_id             :integer
#  amendment_id        :integer
#  filename            :string(255)
#  ayes                :integer          default(0)
#  nays                :integer          default(0)
#  abstains            :integer          default(0)
#  presents            :integer          default(0)
#  democratic_position :boolean
#  republican_position :boolean
#  is_hot              :boolean          default(FALSE)
#  title               :string(255)
#  hot_date            :datetime
#  page_views_count    :integer
#

FactoryGirl.define do
  factory :roll_call do
    number 511
    where "house"
    date "Tue, 19 Jun 2007 13:14:00 EDT -04:00"
    updated "Thu, 13 Sep 2007 08:34:29 EDT -04:00"
    roll_type "On Agreeing to the Amendment"
    question "On Agreeing to the Amendment: Amendment 11 to H R 2641"
    required "1/2"
    result "Failed"
    amendment_id 12723
    filename nil
    ayes 123
    nays 303
    abstains 11
    presents 0
    democratic_position false
    republican_position true
    is_hot nil
    title nil
    hot_date nil
    page_views_count 37

    bill
  end
end

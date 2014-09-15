# == Schema Information
#
# Table name: articles
#
#  id                  :integer          not null, primary key
#  title               :string(255)
#  article             :text
#  created_at          :datetime
#  updated_at          :datetime
#  published_flag      :boolean
#  frontpage           :boolean          default(FALSE)
#  user_id             :integer
#  render_type         :string(255)
#  frontpage_image_url :string(255)
#  excerpt             :text
#  fti_names           :public.tsvector
#

# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :article do
    tag_list 'foo,bar,baz'
  end
end


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
#  fti_names           :tsvector
#

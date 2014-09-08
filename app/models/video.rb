# == Schema Information
#
# Table name: videos
#
#  id          :integer          not null, primary key
#  person_id   :integer
#  bill_id     :integer
#  embed       :text
#  title       :string(255)
#  source      :string(255)
#  video_date  :date
#  created_at  :datetime
#  updated_at  :datetime
#  description :text
#  url         :string(255)
#  length      :integer
#

class Video < OpenCongressModel 
  belongs_to :person
  belongs_to :bill
  
  def atom_id_as_entry
    "tag:opencongress.org,#{created_at.strftime("%Y-%m-%d")}:/video/#{id}"
  end
end

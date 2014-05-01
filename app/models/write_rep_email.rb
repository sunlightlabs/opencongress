# == Schema Information
#
# Table name: write_rep_emails
#
#  id         :integer          not null, primary key
#  user_id    :integer
#  prefix     :string(255)
#  fname      :string(255)
#  lname      :string(255)
#  address    :string(255)
#  zip5       :string(255)
#  zip4       :string(255)
#  city       :string(255)
#  state      :string(255)
#  district   :string(255)
#  person_id  :integer
#  email      :string(255)
#  phone      :string(255)
#  subject    :string(255)
#  msg        :text
#  result     :string(255)
#  ip_address :string(255)
#  created_at :datetime
#  updated_at :datetime
#

class WriteRepEmail < ActiveRecord::Base
  belongs_to :user
  belongs_to :person
  has_many :write_rep_email_msgids
  
  validates_presence_of :prefix, :fname, :lname, :msg, :email, :state
  validates_presence_of :address, :city, :state, :zip5
end

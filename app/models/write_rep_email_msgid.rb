# == Schema Information
#
# Table name: write_rep_email_msgids
#
#  id                 :integer          not null, primary key
#  write_rep_email_id :integer
#  person_id          :integer
#  status             :string(255)
#  msgid              :integer
#  created_at         :datetime
#  updated_at         :datetime
#

class WriteRepEmailMsgid < OpenCongressModel
  belongs_to :write_rep_email
  belongs_to :person
end

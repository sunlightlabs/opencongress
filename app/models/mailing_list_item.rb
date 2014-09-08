# == Schema Information
#
# Table name: mailing_list_items
#
#  id                   :integer          not null, primary key
#  mailable_type        :string(255)
#  mailable_id          :integer
#  user_mailing_list_id :integer
#  created_at           :datetime
#  updated_at           :datetime
#

class MailingListItem < OpenCongressModel
  belongs_to :user_mailing_list
  belongs_to :mailable, :polymorphic => true
  
  scope :people, :conditions => ["mailable_type = 'Person'"]
  scope :bills, :conditions => ["mailable_type = 'Bill'"]
  
end

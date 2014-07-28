# == Schema Information
#
# Table name: contact_congress_letters
#
#  id               :integer          not null, primary key
#  user_id          :integer
#  disposition      :string(255)
#  created_at       :datetime
#  updated_at       :datetime
#  receive_replies  :boolean          default(TRUE)
#  contactable_id   :integer
#  contactable_type :string(255)
#  is_public        :boolean          default(FALSE)
#

require_dependency 'viewable_object'
class ContactCongressLetter < ActiveRecord::Base
  include ViewableObject

  has_many :formageddon_threads, :through => :contact_congress_letters_formageddon_threads, :class_name => 'Formageddon::FormageddonThread'
  has_many :contact_congress_letters_formageddon_threads

  belongs_to :contactable, :polymorphic => true
  belongs_to :user

  has_many :comments, :as => :commentable

  def ident
    "ContactCongressLetter #{id}"
  end

  def to_param
    subject = formageddon_threads.first.formageddon_letters.first.subject
    subject.blank? ? "#{id}" : "#{id}-#{subject.gsub(/[^a-z0-9]+/i, '-')}"
  end

  def subject
    formageddon_threads.first.formageddon_letters.first.subject
  end

  def message
    formageddon_threads.first.formageddon_letters.first.message
  end

  ##
  # Returns the the letter message and stripping away any PII.
  #
  def message_no_pii
    regexp = Regexp.new('(,| +)*' + '((' + user.full_name() + ')(' + (user.mailing_address().strip().gsub(/, /,")?(")) + ')?(,|\s)*')
    return message().gsub(regexp,"")
  end

  def privacy
    formageddon_threads.first.privacy
  end

  def public?
    privacy == 'PUBLIC'
  end
end

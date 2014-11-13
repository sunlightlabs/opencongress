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
#  source           :integer
#

# require_dependency 'viewable_object'
# require 'state'

class ContactCongressLetter < OpenCongressModel

  #========== INCLUDES

  include ViewableObject
  include PrivacyObject
  include ContactCongressLettersHelper

  #========== CONSTANTS

  # This is the source from which the letter originated.
  SOURCES = {
    :other => 0,
    :email => 1,
    :browser => 2
  }

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :contactable, :polymorphic => true
  belongs_to :user

  #----- HAS_MANY

  has_many :formageddon_threads, :through => :contact_congress_letters_formageddon_threads, :class_name => 'Formageddon::FormageddonThread'
  has_many :contact_congress_letters_formageddon_threads
  has_many :formageddon_letters, -> { order('created_at DESC') },
           :through => :formageddon_threads
  has_many :comments, :as => :commentable

  #========== SCOPES

  scope :browser, lambda { where('source = ?', 2) }
  scope :email, lambda { where('source = ?', 1) }

  #========== METHODS

  #----- INSTANCE

  public

  SOURCES.each {|key,val| define_method("from_#{key.to_s}?"){ source == val } }

  def source=(val)
    if val.is_a? Integer
      super val
    elsif val.is_a? Symbol
      super SOURCES[val]
    end
  end

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

  def sender_full_name
    "#{formageddon_threads.first.sender_first_name} #{formageddon_threads.first.sender_last_name}"
  end

  def get_letter
    formageddon_threads.first
  end

  def regarding
    if contactable_type == 'Bill'
      "#{contactable.typenumber} #{contactable.title_common}"
    elsif contactable_type == 'Subject'
      contactable.term
    end
  end

  # Retrieves all the letters on each associated formageddon thread.
  def get_additional_letters
    formageddon_letters
    # TODO: this may not work but we won't be able to tell until formageddon is working on the beta branch
    #letters = []
    #formageddon_threads.each {|t| letters << t.formageddon_letters[1..-1] if t.formageddon_letters.size > 1 }
    #letters.flatten!.sort!{|a,b| a.created_at <=> b.created_at } unless letters.empty?
    #letters
  end

  # TODO: deprecate me
  def can_be_read_by?(viewer)
    formageddon_threads.first.privacy =~ /PRIVATE/ ?  (viewer != :false && viewer == user) : true
  end

  ##
  # Returns the the letter message and stripping away any PII using a regexp.
  # At the time of writing, 7/29/2014, this is not a good long term solution.
  # The problem is that street_address_2 was not properly storing to the UserProfile
  # model yet was being appended as part of the message body in congress letters.
  # This regexp attempts to catches PII and anything that comes after until a newline
  # appears. Unfortunately doing this may eliminate some letter text if a person
  # chooses to throw in their full name randomly in the body of their message.
  #
  def message_no_pii
    strip_pii_from_message(get_letter, message)
  end

  def privacy
    formageddon_threads.first.privacy
  end

  def public?
    privacy == 'PUBLIC'
  end

end

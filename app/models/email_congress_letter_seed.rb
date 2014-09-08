# == Schema Information
#
# Table name: email_congress_letter_seeds
#
#  id                         :integer          not null, primary key
#  raw_source                 :text
#  sender_email               :string(255)
#  sender_title               :string(255)
#  sender_first_name          :string(255)
#  sender_last_name           :string(255)
#  sender_street_address      :string(255)
#  sender_street_address_2    :string(255)
#  sender_city                :string(255)
#  sender_state               :string(255)
#  sender_zipcode             :string(255)
#  sender_zip_four            :string(255)
#  sender_mobile_phone        :string(255)
#  email_subject              :string(255)
#  email_body                 :text
#  resolved                   :boolean          default(FALSE)
#  resolved_at                :datetime
#  resolution                 :string(255)
#  confirmation_code          :string(255)
#  contact_congress_letter_id :integer
#  created_at                 :datetime
#  updated_at                 :datetime
#

require_dependency 'email_congress'

class EmailCongressLetterSeed < OpenCongressModel
  belongs_to :contact_congress_letter

  before_validation :generate_confirmation_code
  validates_uniqueness_of :confirmation_code
  validates_length_of :email_body, :maximum => 25000, :message => 'Please shorten the body of your message', :allow_blank => true

  scope :unresolved, lambda { where(:resolved => false) }

  def confirmed?
    return (resolution == 'confirmation')
  end

  def confirm!
    self.resolved = true
    self.resolution = 'confirmation'
    save!
  end

  # TODO: deprecate me
  def confirm
    self.resolved = true
    self.resolution = 'confirmation'
    save!
  end

  def generate_confirmation_code
    # Generate a confirmation_code, if needed
    if self.confirmation_code.blank?
      self.generate_confirmation_code!
    end
  end

  def generate_confirmation_code!
    # Generating a confirmation_code, overwriting any existing code
    10.times.each do |n|
      bits = Settings.to_hash.fetch('email_congress_confirmation_code_bits', 256)
      candidate = SecureRandom.random_number(2 ** bits).to_s(36)
      unique = (EmailCongressLetterSeed.where(:confirmation_code => candidate).count() == 0)
      next if !unique
      self.confirmation_code = candidate
      return self.confirmation_code
    end
    # TODO: This should probably be a more specific exception class
    raise 'Unable to generate a unique confirmation code'
  end

  def sender_user
    User.find_by_email(sender_email)
  end

  def raw_recipient_addresses
    @recipient_addresses ||= JSON.load(raw_source).values_at("ToFull", "CcFull", "BccFull").flatten.compact.map{|o| o["Email"] }.uniq
  end

  def clean_recipient_list
    return @clean_recipient_list unless @clean_recipient_list.nil?
    @clean_recipient_list = EmailCongress.cleaned_recipient_list(sender_user, raw_recipient_addresses)
  end

  def allowed_recipient_addresses
    return clean_recipient_list.map(&:first)
  end

  def rejected_recipient_addresses
    requested = Set.new(raw_recipient_addresses)
    lc_allowed = Set.new(allowed_recipient_addresses.map(&:downcase))
    rejected = requested.reject{ |a| lc_allowed.include?(a.downcase) }
    return rejected.to_a
  end

  def allowed_recipients
    return clean_recipient_list.map(&:second)
  end
end

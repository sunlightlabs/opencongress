class EmailCongressLetterSeed < ActiveRecord::Base
  # TODO: Add a job to clean up older seeds

  before_validation :generate_confirmation_code
  validates_uniqueness_of :confirmation_code

  scope :unresolved, lambda { where(:resolved => false) }

  def confirmed?
    return (resolution == 'confirmation')
  end

  def confirm!
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
      candidate = SecureRandom.random_number(2**16).to_s(36)
      # TODO: candidate = SecureRandom.random_number(2**256).to_s(36)
      unique = (EmailCongressLetterSeed.where(:confirmation_code => candidate).count() == 0)
      next if !unique
      self.confirmation_code = candidate
      return self.confirmation_code
    end
    # TODO: This should probably be a more specific exception class
    raise 'Unable to generate a unique confirmation code'
  end
end

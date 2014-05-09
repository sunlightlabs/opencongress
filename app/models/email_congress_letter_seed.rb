class EmailCongressLetterSeed < ActiveRecord::Base
  # TODO: Add a job to clean up older seeds

  before_save :generate_confirmation_code

  #has_many :formageddon_recipient, :polymorphic => true # TODO: Add table info to avoid coupling formageddon to this feature.

  scope :unresolved, lambda { where(:resolved => false) }

  def confirm!
    self.resolved = true
    self.resolution = 'confirmation'
    save!
  end

  private
  def generate_confirmation_code
    if self.confirmation_code.blank?
      self.generate_confirmation_code!
    end
    self.confirmation_code
  end

  def generate_confirmation_code!
    # TODO: This should be in a transaction that retries if the uniqueness constraint fails.
    self.confirmation_code = SecureRandom.random_number(2**16).to_s(36)
    self.confirmation_code = SecureRandom.random_number(2**256).to_s(36)
  end
end

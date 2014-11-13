require 'digest/sha1'

# Handles authentication-related tasks for a model
module Authable

  extend ActiveSupport::Concern

  class LoginTakenException < Exception

  end

  included do

    has_secure_password validations: false # because User model is validating password

    before_create :make_activation_code
    before_save   :encrypt_password

    attr_accessor :plaintext_password, :password_confirmation, :current_password, :remember_token_expires_at
    # Further, the following fields should be defined in your AR model
    #
    # attr_accessor :status, :activated_at, :activation_code, :remember_token,
    #               :crypted_password, :password_reset_code, :email

    scope :unconfirmed, -> { where(status: STATUSES[:unconfirmed]) }
    scope :authorized, -> { where("status > 0 and status < #{STATUSES[:deleted]}") }
    scope :banned, -> { where(status: STATUSES[:banned]) }
    scope :deleted, -> { where(status: STATUSES[:deleted]) }

    # to make the authentication method more clear
    alias_method :bcrypt_authenticate, :authenticate
    # allows user to access the password attribute through a
    # common interface (instead of from has_secure_password)
    alias_method :bcrypt_password=, :password=
    def password ; self.plaintext_password ; end
    def password=(password) ; self.plaintext_password = password ; end

  end

  #========== CONSTANTS

  STATUSES = {
      :unconfirmed => 0,
      :active => 1,
      :email_only => 2,
      :reaccept_tos => 3,
      :deleted => 5,
      :banned => 6
  }

  #========== METHODS

  #----- CLASS

  module ClassMethods

    # Authenticates a user by their login/email and unencrypted password.
    #
    # @param login [String] user's login or email
    # @param password [String] user's plaintext password
    # @return [User, nil] authenticated user or nil
    def authenticate(login, password)
      # check if input is an email or login
      param = login.match(/^[\w\-_+\.]+@[\w\-_\.]+$/) ? 'email' : 'login'
      # check if user exists and is allowed to login
      user = User.authorized.where(["lower(#{param}) = ?", login.downcase]).first
      # nil if user doesn't eixst
      return nil if user.nil?
      # try to authenticate with bcrypt password
      return user.bcrypt_authenticate(password) if user.has_bcrypt_password?
      # otherwise try to authenticate with sha1 password
      sha1u = user.sha1_authenticate(password)
      # if sha1 authenticated, get a bcrypt password for next login
      sha1u.update_attribute('bcrypt_password', password) if sha1u.present?
      sha1u
    end

    # Encrypts data with the provided salt.
    #
    # @param password [String] the password to encrypt
    # @param salt [String] salt to encrypt password with
    # @return [String] password encrypted with SHA1
    def sha1_encrypt(password, salt)
      Digest::SHA1.hexdigest("--#{salt}--#{password}--")
    end

  end

  #----- INSTANCE

  public

  # Convenience method for setting password and password_confirmation in one method call
  #
  # @param password [String] plaintext password
  # @param confirmation [String] plaintext password confirmation
  def set_password(password, confirmation)
    self.password = password
    self.password_confirmation = confirmation
  end

  # Checks if password matches password_confirmation
  #
  # @return [Boolean] true if match, false otherwise
  def password_matches_confirmation?
    self.password == self.password_confirmation
  end

  # Displays the status of the User as a string
  #
  # @return [String] User status as a string
  def status_display
    STATUSES.invert[status].to_s
  end

  # Humanized explanation of the User's status
  #
  # @return [String, nil] humanized explanation of User's status
  def status_explanation
    case status_display
      when 'deleted'
        'This user has deleted their account.'
      when 'banned'
        'This user has been banned.'
      else
        nil
    end
  end

  # Checks if user is unconfirmed.
  #
  # @return [Boolean] true if unconfirmed, false otherwise
  def is_unconfirmed?
    status == STATUSES[:unconfirmed]
  end

  # Checks if user is authorized.
  #
  # @return [Boolean] true if authorized, false otherwise
  def is_authorized?
    status < STATUSES[:deleted]
  end

  # Checks if user is active.
  #
  # @return [Boolean] true if active, false otherwise
  def is_active?
    !is_unconfirmed? && is_authorized?
  end
  alias_method :activated?, :is_active?
  alias_method :enabled, :is_active?

  # Checks if user is banned.
  #
  # @return [Boolean] true if banned, false otherwise
  def is_banned?
    status == STATUSES[:banned]
  end
  alias_method :is_banned, :is_banned?

  # Checks if user is deactivated.
  #
  # @return [Boolean] true if deactivated, false otherwise
  def is_deactivated?
    status == STATUSES[:deleted]
  end

  # Checks if a user can log in.
  #
  # @return [Boolean] true if user can log in, false otherwise
  def can_login?
    status < STATUSES[:deleted]
  end
  alias_method :can_use_site?, :is_active?

  # Activates the user in the database.
  def activate!
    @activated = true
    update_attributes(activated_at: Time.now, activation_code: nil, status: 1)
  end

  # Checks if user has been recently activated
  #
  # @return [Boolean] true if recently activated
  def recently_activated?
    @activated
  end

  # Bans this user
  def ban!
    if status < STATUSES[:banned]
      self.login = get_unique_login_for_status(:banned)
      self.status = STATUSES[:banned]
      save :validate => false
    end
  end

  # Unbans this user
  def unban!
    begin
      recover_login!
      self.status = STATUSES[:active]
      save
    rescue Exception => e
      errors.add :base, e
      false
    end
  end

  # for legacy compatibility
  def is_banned=(val)
    !!val ? ban! : unban!
  end

  def deactivate!
    if self.status < STATUSES[:deleted]
      self.login = get_unique_login_for_status(:deleted)
      self.status = STATUSES[:deleted]
      save :validate => false
    end
  end
  alias_method :reactivate!, :unban!

  # Encrypts the password with the User's salt
  #
  # @param password [String] encrypt password using SHA1
  # @return [String] encrypted password
  def sha1_encrypt(password)
    self.class.sha1_encrypt(password, salt)
  end

  # Checks if user has a bcrypted password
  #
  # @return [Boolean] true if User has a password_digest, false otherwise
  def has_bcrypt_password?
    self.password_digest.present?
  end

  # Checks if the plaintext password is correct using sha1
  #
  # @param password [String] plaintext password
  # @return [Boolean] true if correct, false otherwise
  def sha1_authenticated?(password)
    puts "crypted: #{crypted_password} :: encrypt(password): #{sha1_encrypt(password)}"
    self.crypted_password == sha1_encrypt(password)
  end

  # Authenticate with SHA1 password
  #
  # @param password [String] plaintext password
  # @return [User, nil] User if password is correct, false otherwise
  def sha1_authenticate(password)
    self.crypted_password == sha1_encrypt(password) ? self : nil
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    self.remember_token_expires_at = 8.weeks.from_now.utc
    self.remember_token            = sha1_encrypt("#{email}--#{remember_token_expires_at}")
    save(:validate => false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(:validate => false)
  end

  def forgot_password
    @forgotten_password = true
    make_password_reset_code
  end

  def reset_password
    # First update the password_reset_code before setting the
    # reset_password flag to avoid duplicate email notifications.
    self.update_attribute(:password_reset_code, nil)
    @reset_password = true
    self.activate! if self.activated_at.nil?
  end

  def recently_reset_password?
    @reset_password
  end

  def recently_forgot_password?
    @forgotten_password
  end

  protected

  def make_password_reset_code
    self.password_reset_code = Digest::SHA1.hexdigest( Time.now.to_s.split(//).sort_by {rand}.join )
  end

  # Encrypts the plaintext password and stores it in the User model
  def encrypt_password
    return if password.blank?
    self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
    # sha1 password - TODO deprecate me
    self.crypted_password = sha1_encrypt(password)
    # bcrypt password - note this does not store the plaintext_password, see has_secure_password module
    self.bcrypt_password = password
    # get rid of plaintext password
    self.password = nil
  end

  def make_activation_code
     self.activation_code = Digest::SHA1.hexdigest(Time.now.to_s.split(//).sort_by {rand}.join)
  end

  def get_unique_login_for_status(status)
    _slug = slug = "[#{status}:#{login}]"
    serial = 0
    while User.find_by_login(slug).present?
      serial += 1
      slug = "#{_slug}#{serial.to_s}"
    end
    slug
  end

  def recover_login!
    original_login = login.match(/^\[[a-z]+:(.+)\]$/)[1] rescue nil
    existing = User.find_by_login(original_login)
    if existing.nil?
      self.login = original_login
    else
      raise LoginTakenException.new('Login is no longer available')
    end
  end

end
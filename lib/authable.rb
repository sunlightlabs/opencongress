module Authable
  # Handles authentication-related tasks for a model

  class LoginTakenException < Exception
  end

  extend ActiveSupport::Concern

  def included(base)
    base.extend(ClassMethods)
    attr_accessible :login, :password, :password_confirmation, :remember_token
    attr_accessor :password, :remember_token_expires_at
    ##
    # Further, the following fields should be defined in your AR model
    #
    # attr_accessor :status, :activated_at, :activation_code, :remember_token,
    #               :crypted_password, :password_reset_code, :email
  end

  module ClassMethods
    # Authenticates a user by their login name and unencrypted password.  Returns the user or nil.
    def authenticate(login, password)
      u = find :first, :conditions => ['LOWER(login) = ? and activated_at IS NOT NULL and enabled = true AND is_banned != true', login.downcase]
      if u && u.authenticated?(password)
        # u.update_attribute(:previous_login_date, u.last_login ? u.last_login : Time.now)
        # u.update_attribute(:last_login, Time.now)
        u
      else
        nil
      end
    end

    # Encrypts some data with the salt.
    def encrypt(password, salt)
      Digest::SHA1.hexdigest("--#{salt}--#{password}--")
    end

  end

  STATUSES = {
    :unconfirmed => 0,
    :active => 1,
    :deleted => 5,
    :banned => 6
  }

  def is_unconfirmed?
    status == STATUSES[:unconfirmed]
  end

  def is_active?
    status && status < STATUSES[:deleted]
  end
  alias_method :activated?, :is_active?

  # Activates the user in the database.
  def activate!
    @activated = true
    self.update_attribute(:activated_at, Time.now)
    self.update_attribute(:activation_code, nil)
    self.update_attribute(:status, 1)
  end

  # Returns true if the user has just been activated.
  def recently_activated?
    @activated
  end

  def is_banned?
    status == STATUSES[:banned]
  end
  alias_method :is_banned, :is_banned?

  def ban!
    if status < STATUSES[:banned]
      self.login = get_unique_login_for_status(:banned)
      self.status = STATUSES[:banned]
      save
    end
  end

  def unban!
    try_to_recover_login
    self.status = STATUSES[:active]
    save
  rescue e
    self.errors << e
    false
  end

  def is_banned=(val)
    if !!val
      ban!
    else
      unban!
    end
  end

  def is_deactivated?
    status == STATUSES[:deleted]
  end

  def deactivate!
    if self.status < STATUSES[:deleted]
      self.login = get_unique_login_for_status(:deleted)
      self.status = STATUSES[:deleted]
      save
    end
  end

  alias_method :reactivate!, :unban!

  def can_login?
    status < STATUSES[:deleted]
  end

  alias_method :can_use_site?, :is_active?

  # Encrypts the password with the user salt
  def encrypt(password)
    self.class.encrypt(password, salt)
  end

  def authenticated?(password)
    puts "crypted: #{crypted_password} :: encrypt(password): #{encrypt(password)}"
    crypted_password == encrypt(password)
  end

  def remember_token?
    remember_token_expires_at && Time.now.utc < remember_token_expires_at
  end

  # These create and unset the fields required for remembering users between browser closes
  def remember_me
    self.remember_token_expires_at = 8.weeks.from_now.utc
    self.remember_token            = encrypt("#{email}--#{remember_token_expires_at}")
    save(false)
  end

  def forget_me
    self.remember_token_expires_at = nil
    self.remember_token            = nil
    save(false)
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

  # before filter
  def encrypt_password
     return if password.blank?
     self.salt = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{login}--") if new_record?
     self.crypted_password = encrypt(password)
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
      raise LoginTakenException.new("Login is no longer available")
    end
  end

end
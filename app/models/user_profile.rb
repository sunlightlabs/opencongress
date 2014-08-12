# == Schema Information
#
# Table name: user_profiles
#
#  id               :integer          not null, primary key
#  user_id          :integer
#  first_name       :string(255)
#  last_name        :string(255)
#  website          :string(255)
#  about            :text
#  main_picture     :string(255)
#  small_picture    :string(255)
#  street_address   :string(255)
#  street_address_2 :string(255)
#  city             :string(255)
#  zipcode          :string(5)
#  zip_four         :string(4)
#  mobile_phone     :string(255)
#

require_dependency 'full-name-splitter'
require_dependency 'location_changed_service'

class UserProfile < ActiveRecord::Base

  #========== RELATIONS

  belongs_to :user

  #========== VALIDATORS

  validates_numericality_of   :zipcode, :only_integer => true, :allow_blank => true, :message => 'should be all numbers'
  validates_numericality_of   :zip_four, :only_integer => true, :allow_blank => true, :message => 'should be all numbers'
  validates_length_of         :zipcode, :is => 5, :allow_blank => true, :message => 'should be 5 digits'
  validates_length_of         :zip_four, :is => 4, :allow_blank => true, :message => 'should be 4 digits'

  #========== DELEGATED ATTRIBUTES / METHODS

  delegate :state,  :to => :user
  delegate :state=, :to => :user
  delegate :state_changed?, :to => :user
  delegate :district_needs_update?, :to => :user, :prefix => true

  #========== CONSTANTS

  HUMANIZED_ATTRIBUTES = {
      :zip_four => "ZIP code +4 extension",
      :zipcode => "ZIP code",
      :street_address_2 => "Street address 2nd line"
  }

  #========== CALLBACKS

  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!IMPORTANT!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  # 7/15/2014: Clayton discovered that rail's postgresql adapter relies on database primary key designation (index)
  # to spit back ID fields to the model object. If it can't, child models that depend on the ID will fail to save
  # properly. Tim discovers that pg_dump wasn't preserving the the indexes (such as primary keys) so when the
  # local database wasn't being built fully. Never forget this struggle to discovery.
  after_save  :change_location!


  #========== PUBLIC METHODS
  public

  ##
  # Updates the user's location if any of his address attributes change.
  #
  def change_location!
    if zipcode_changed?                   ||
       zip_four_changed?                  ||
       street_address_changed?            ||
       street_address_2_changed?          ||
       city_changed?                      ||
       (state.blank? && zipcode.present?) ||
       user_district_needs_update?
        LocationChangedService.new(user)
    end
  end

  ##
  # Getter for a concatenation of first and last name
  #
  def full_name
    "#{first_name} #{last_name}"
  end

  ##
  # Setter for first and last name using a sophisticated full name splitter
  #
  def full_name=(name)
    self.first_name, self.last_name = FullNameSplitter.split name
  end

  ##
  # Getter for location
  #
  def location
    if city.present? && state.present?
      "#{city}, #{state}"
    elsif state.present?
      state
    elsif city.present?
      city
    end
  end

  ##
  # Getter for mailing address by concatenating various address attributes
  #
  # @return {String}  representing full mailing address
  #
  def mailing_address
    addr = ''
    if street_address.present?
      addr += "#{street_address}"
      if street_address_2.present?
        addr += " #{street_address_2},"
      else
        addr += ','
      end
      addr += '' if state.present? || zipcode.present?
    end
    if state.present?
      addr += "#{city}, " if city.present?
      addr += "#{state}"
    end
    addr += " #{zipcode}" if zipcode.present?
    addr += "-#{zip_four}" if zip_four.present?

    addr
  end

  ##
  # Getter for mailing address by building a Hash
  #
  # @return {Hash}  representing full mailing address
  #
  def mailing_address_as_hash
    {
      :street_address => street_address,
      :street_address_2 => street_address_2,
      :city => city,
      :state => state,
      :zipcode => zipcode,
      :zip_four => zip_four
    }
  end

end
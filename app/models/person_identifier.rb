# == Schema Information
#
# Table name: person_identifiers
#
#  id         :integer          not null, primary key
#  person_id  :integer
#  bioguideid :string(255)
#  namespace  :text
#  value      :text
#  created_at :datetime
#  updated_at :datetime
#

class PersonIdentifier < ActiveRecord::Base
  
  #========== INCLUDES

  #========== RELATIONS

  belongs_to :person

  #========== CONSTANTS

  #========== VALIDATORS

  validates :value,
            :uniqueness => {
                :scope => :namespace,
                :case_sensitive => true,
                :message => "must be unique within namespace"
            },
            :presence => true
  validates :namespace,
            :presence => true

  #========== FILTERS

  before_validation :downcase_namespace

  #========== METHODS

  #----- CLASS

  #----- INSTANCE

  #========== VALIDATIONS
  
  validates :value,
            :uniqueness => {
                :scope => :namespace,
                :case_sensitive => true,
                :message => "must be unique within namespace"
            },
            :presence => true
  validates :namespace,
            :presence => true

  #========== FILTERS

  before_validation :downcase_namespace

  #========== METHODS

  #----- CLASS

  #----- INSTANCE

  public

  def downcase_namespace
    self.namespace = self.namespace.downcase rescue false
  end

end
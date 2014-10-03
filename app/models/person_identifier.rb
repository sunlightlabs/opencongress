class PersonIdentifier < ActiveRecord::Base
  
  #========== INCLUDES

  #========== RELATIONS
  belongs_to :person

  #========== CONSTANTS

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
  attr_accessible :value, :namespace
  before_validation :downcase_namespace

  #========== PUBLIC METHODS  
  def downcase_namespace
    self.namespace = self.namespace.downcase rescue false
  end

end

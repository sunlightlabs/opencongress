module SearchableObject
  extend ActiveSupport::Concern

  included do
    include Elasticsearch::Model
    include Elasticsearch::Model::Callbacks
  end

  #========== METHODS

  #----- CLASS

  def self.abstract_class?
    true
  end

  module ClassMethods

  end

  #----- INSTANCE

end
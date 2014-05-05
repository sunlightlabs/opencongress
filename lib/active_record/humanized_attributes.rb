##
# Mixes in a human_attribute_name override for all models
module ActiveRecord
  class Base
    HUMANIZED_ATTRIBUTES = {}

    def self.human_attribute_name(attr, options = {})
      self.const_get('HUMANIZED_ATTRIBUTES')[attr.to_sym] || super
    end
  end
end
# At CoverHound, we use conditional validations all over the form. However, there is no proper way to do
# this in Rails. Instead, we can provide an array of attributes (validated_fields attribute)
# and ensure they are the only ones to get validated.
#
# @documentation  http://coverhound.com/blog/post/better-conditional-validations-in-rails
# @source         https://gist.github.com/ibanez270dx/4955453
module ConditionalValidations
  attr_accessor :validated_fields

  def field_is_required?(field)
    unless validated_fields.blank?
      validated_fields.include?(field)
    end
  end

  def conditionally_validate(attribute, options=nil)
    unless options.nil?
      # Passing options for built-in validators
      # http://guides.rubyonrails.org/active_record_validations_callbacks.html#validation-helpers
      unless options[:if].nil?
        options[:if] = "#{options[:if]} && field_is_required?(:#{attribute})"
        validates attribute, options
      else
        validates attribute, options.merge(if: "field_is_required?(:#{attribute})")
      end
    else
      # Block validation
      # will initiate a validator on attribute using a method called validate_#{attribute}
      validate :"validate_#{attribute}", if: "field_is_required?(:#{attribute})"
    end
  end

  def fields_valid?(fields)
    # Note that when validations are run, class variable @errors changes. As such, we have
    # to keep track of whether there were errors originally and repopulate them as necessary.
    original_errors = self.errors.messages.count

    mock = self.dup                       # duplicate the model in a non-persisted way.
    mock.validated_fields = fields        # ...tell model what fields to validate.
    validity = mock.valid?                # run validations and change @errors.

    # If there were errors on the original model, run valid? so that it populates @errors.
    # Otherwise, remove any errors left over from the mock run.
    (original_errors > 0) ? self.valid? : self.errors.clear
    return validity
  end
end

ActiveRecord::Base.extend ConditionalValidations
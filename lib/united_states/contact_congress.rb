require 'yaml'

module UnitedStates
  module ContactCongress
    extend self

    class UnmappedField < Exception
    end

    # CONSTANTS_PATH = File.join Settings.data_path, "congress-contact", "support", "constants.yaml"
    CONSTANTS_PATH = "/users/dan/Code/git/sun/congress-contact/support/constants.yaml"
    VARIABLES_PATH = "/users/dan/Code/git/sun/congress-contact/support/variables.yaml"

    def constants
      @@constants ||= YAML.load(File.read(CONSTANTS_PATH))
    end

    def get_field_value(name, opts={})
      @@variables ||= {
        '$NAME_PREFIX' => 'title',
        '$NAME_FIRST' =>  'first_name',
        '$NAME_LAST' =>   'last_name',
        '$ADDRESS_STREET' => 'address1',
        '$ADDRESS_STREET_2' => 'address2',
        '$ADDRESS_CITY' => 'city',
        '$ADDRESS_STATE' => 'state',
        '$ADDRESS_STATE_POSTAL_ABBREV' => 'state',
        '$ADDRESS_ZIP5' => 'zip5',
        '$ADDRESS_ZIP4' => 'zip4',
        '$PHONE' => 'phone',
        '$EMAIL' => 'email',
        '$TOPIC' => 'issue_area',
        '$SUBJECT' => 'subject',
        '$MESSAGE' => 'message',
      }
      val = @@variables[name] || 'leave_blank'
      raise UnmappedField.new("#{name} has no mapping") if (opts[:required] && val == 'leave_blank')
      val
    end


    # Returns a contact steps hash from a file path
    def parse_contact_file(path)
      decode_contact_hash(YAML.load(File.read(path)))
    end

    # Returns a decoded contact steps hash, muxing a raw contact_file hash
    # with the constants defined in the unitedstates/contact_congress repo's support folder
    def decode_contact_hash(hsh)
      hsh['contact_form']['steps'].each do |step|
        step.to_enum.each do |action, items|
          if items.is_a? Array
            items.each do |item|
              item.to_enum.each do |property, value|
                if is_const?(value)
                  item[property] = constants[value]['value'] rescue value
                end
              end
            end
          end
        end
      end
      hsh
    end

    # Sets up a person's Formageddon contact environment
    # person is a Person instance
    def import_contact_steps_for(person, path)
      hsh = parse_contact_file(path)
      current_step = nil  # formageddon steps can span multiple directives here, ex. 'fill_in', 'select' and 'click_on'. This acts as a cursor.
      person.formageddon_contact_steps.destroy_all
      steps = hsh['contact_form']['steps']
      steps.each do |step|

        step.each do |action, values|
          next if action == 'find'

          # These steps get grouped together as 'submit_form' in formageddon
          if ['fill_in', 'select', 'check', 'uncheck', 'choose'].include? action
            # Build a step if it doesn't already exist
            person.formageddon_contact_steps << (current_step = Formageddon::FormageddonContactStep.new(
              :command => 'submit_form'
            )) if current_step.nil?

            # Build a form if the step doesn't have one, because this is a submit_form step
            current_step.formageddon_form = Formageddon::FormageddonForm.new(
              :use_field_names => true,
              :success_string => (hsh['contact_form']['success']['body']['contains'] rescue 'Thank you')
            ) if current_step.formageddon_form.nil?

            # Map the field values for each item in the step and add a field instance to the form
            form = current_step.formageddon_form
            values.each do |item|
              if action == "check"
                # Set the value from the YAML if this is a checkbox
                value = item['value']
              else
                # Otherwise resolve it through our variable map
                value = get_field_value(item['value'], :required => item['required'])
              end

              # Append the field to the form
              form.formageddon_form_fields << Formageddon::FormageddonFormField.new(
                :name => item['name'],
                :css_selector => item['selector'],
                :required => item['required'] || false,
                :value => value
              )
              # Email fields might have a 'disallow_plus' parameter, if the plus hack will trigger the form to fail.
              # In these cases set a flag on the form
              form.use_real_email_address = true if item['value'] == '$EMAIL' && item['disallow_plus']
            end

          # Remaining steps are either the initial visiting of a page, or no-ops.
          # TODO: Deal with CAPTCHAs
          else
            # Add the button selector to the form if this is a click on step.
            if action == 'click_on'
              if current_step.present? && current_step.formageddon_form.present?
                current_step.formageddon_form.submit_css_selector = values.first['selector']
                current_step.formageddon_form.save!
              end
            end
            # If there's a step open and we've gotten here, we're done collecting
            # fields to fill out and it's time to save and assign it.
            unless current_step.nil?
              current_step.save!
              person.formageddon_contact_steps << current_step
              current_step = nil
            end

            # 'Visit' steps get their own formageddon step
            if action == 'visit'
              step = Formageddon::FormageddonContactStep.new(:command => "visit::#{values}")
              person.formageddon_contact_steps << step
            end
          end
        end
      end
      person.save!
    end

    protected

    def is_const?(str)
      !! (str =~ /\A[A-Z][A-Z0-9_]*\Z/i)
    end

    def is_var?(str)
      !! (str =~ /\A\$[A-Z][A-Z0-9_]*\Z/i)
    end
  end
end

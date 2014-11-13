module ActiveRecord
  class Base

    # This filter merges the validation errors in a relation with calling instance.
    # This is so the messages aren't prepended by the class name.
    #
    # @param relations [Array<Symbols>] symbols of relations
    def merge_validation_errors_with(*relations)
      relations.each do |rel|
        send(rel).errors.each {|name, value| errors.add(name.to_sym, value) }
        errors.messages.delete_if {|name, value| name.to_s.include? rel.to_s }
      end
    end

  end
end
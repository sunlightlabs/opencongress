class ArrayMemberValidator < ActiveModel::EachValidator

  def validate_each(record, attribute, value)
    record.errors[attribute] << "all members must be in #{options[:in]}" unless (value & options[:in]).size == value.size
  end

end
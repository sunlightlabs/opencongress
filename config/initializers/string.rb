class ::String

  # Checks if String matches zip4 syntax
  #
  # @return [Boolean] true if matches, false otherwise
  def valid_zip4?
    self.match(/\d{4}/)
  end

  # Checks if String matches zip5 syntax
  #
  # @return [Boolean] true if matches, false otherwise
  def valid_zip5?
    self.match(/\d{5}/)
  end

  # Downcases first letter of String
  #
  # @return [String] first letter downcased

  def uncapitalize
    self[0, 1].downcase + self[1..-1]
  end

  # Strips the last period of String if period exists
  #
  # @return [String]

  def strip_period
    self.chomp!('.')
  end

  # Strips all non-alphonumeric characters
  #
  # @return [String]
  def strip_punctuation
    self.downcase.gsub(/[^a-z0-9]/i, '')
  end

  # Strips all non-numeric characters
  #
  # @return [String]
  def strip_all_except_numbers
    self.gsub(/[^0-9]/, '')
  end

  # Check if String is an Integer
  #
  # @return [Boolean] true if Integer, false otherwise
  def is_int?
    !!(str =~ /^[-+]?[1-9]([0-9]*)?$/)
  end

  def strip_newline_and_tabs
    self.gsub(/(\n)+/,'').gsub(/(\t)+/,'')
  end

end
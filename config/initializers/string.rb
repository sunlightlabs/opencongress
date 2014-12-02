class ::String

  def uncapitalize
    self[0, 1].downcase + self[1..-1]
  end

  def strip_period
    self.chomp!('.')
  end

  def strip_punctuation
    self.downcase.gsub(/[^a-z0-9]/i, '')
  end

  def strip_all_except_numbers
    self.gsub(/[^0-9]/, '')
  end

end
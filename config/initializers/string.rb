class ::String

  def valid_zip4?
    self.match(/\d{4}/)
  end

  def valid_zip5?
    self.match(/\d{5}/)
  end

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

  def strip_newline_and_tabs
    self.gsub(/(\n)+/,'').gsub(/(\t)+/,'')
  end

end
class ::String

  def uncapitalize
    self[0, 1].downcase + self[1..-1]
  end

  def strip_period
    self.chomp!('.')
  end

end
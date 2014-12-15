class ::Array

  # Converts array into active record relation. Assumes array contains
  # records of all the same type.
  def to_active_record
    class_name = self.first

  end

end
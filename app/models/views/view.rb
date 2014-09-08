class View < OpenCongressModel
  self.abstract_class = true

  def readonly?
    true
  end
end

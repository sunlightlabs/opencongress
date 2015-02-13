class ::Object

  def send_if_method_exists(method_name)
    send(method_name) if respond_to?(method_name, true)
  end

end
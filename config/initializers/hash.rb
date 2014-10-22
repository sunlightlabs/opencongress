class ::Hash

  # Allows for hash to be accessed with dot notation
  #
  # @param name [Symbol,String] key name
  def method_missing(name)
    return self[name] if key? name
    self.each {|k,v| return v if k.to_s.to_sym == name }
    super.method_missing name
  end

  # Adds and sets default values for input keys
  #
  # @param val [Object] any default value
  # @param keys [Array<Object>] keys to add to Hash
  def init_missing_keys(val, *keys)
    keys.each {|k| self[k] = val unless self.has_key?(k) }
  end

end
class ::Hash

  # Recursively descend hash and change numeric types into strings
  #
  # @param h [Hash] hash to convert
  # @param skip_list [Array<Symbol>] keys of which not to stringify the corresponding value
  def self.ihash(h, skip_list)
    h.each do |k,v|
      if v.is_a?(Hash)
        ihash(v, skip_list)
      else
        h[k] = v.to_s if (v.is_a? Numeric and not skip_list.include?(k))
      end
    end
  end

  # Allows for hash to be accessed with dot notation
  #
  # @param name [Symbol,String] key name
  # @return [Hash] self
  def method_missing(name)
    return self[name] if key? name
    self.each {|k,v| return v if k.to_s.to_sym == name }
    super.method_missing name
  end

  # Adds and sets default values for input keys
  #
  # @param val [Object] any default value
  # @param keys [Array<Object>] keys to add to Hash
  # @return [Hash] self
  def init_missing_keys(val, *keys)
    keys.each {|k| self[k] = val unless self.has_key?(k) }
  end

  # Turns all numerics values into strings
  #
  # @param skip_list [Array<Symbol>] keys of which not to stringify the corresponding value
  # @return [Hash] self
  def stringify_numerics(skip_list)
    Hash.ihash(self, skip_list)
  end

end
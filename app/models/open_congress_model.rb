class OpenCongressModel < ActiveRecord::Base

  #========== ATTRIBUTES

  self.abstract_class = true

  #========== METHODS

  #----- CLASS

  # Retrieves a random number of records from the database
  #
  # @param limit [Integer] limit on how many random records to retrieve
  # @return [Relation<Model>] random relation of models of calling class
  def self.random(limit)
    order('RANDOM()').limit(limit)
  end

  # Callback for after class definition
  def self.after_inherited(child = nil, &blk)
    line_class = nil
    set_trace_func(lambda do |event, file, line, id, binding, classname|
      unless line_class
        # save the line of the inherited class entry
        line_class = line if event == 'class'
      else
        # check the end of inherited class
        if line_class && event == 'end'
          # if so, turn off the trace and call the block
          set_trace_func nil
          blk.call child
        end
      end
    end)
  end

  #----- INSTANCE

  public

  # Sets default attributes for nil attributes as defined by constant DEFAULT_ATTRIBUTES
  def set_default_attributes_for_nil
    self.class::DEFAULT_ATTRIBUTES.each {|k,v| self.send("#{k.to_s}=".to_sym, v) if self.respond_to?(k) and self.send(k).blank? } if defined? self.class::DEFAULT_ATTRIBUTES
  end

end
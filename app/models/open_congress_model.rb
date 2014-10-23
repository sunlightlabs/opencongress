class OpenCongressModel < ActiveRecord::Base

  self.abstract_class = true

  # Insures all descendants have been touched
  # so the descendant array is complete
  #
  # @return [Array<Model>] array of subclasses
  def self.descendants
    Dir.glob(Rails.root.join('app/models/**/*.rb').to_s) {|path| require path }
    super
  end

  # Retrieves all application models in one array
  #
  # @return [Array<Model>] array of all models in application
  def self.all_models
    # must eager load all the classes...
    Dir.glob(Rails.root.join('app/models/**/*.rb').to_s) do |model_path|
      begin
        require model_path
      rescue
        # ignore
      end
    end
    # simply return them
    ActiveRecord::Base.send(:subclasses)
  end

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

  def set_default_attributes_for_nil
    self.class::DEFAULT_ATTRIBUTES.each {|k,v| self.send("#{k.to_s}=".to_sym, v) if self.respond_to?(k) and self.send(k).blank? } if defined? self.class::DEFAULT_ATTRIBUTES
  end

end
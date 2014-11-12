class OpenCongressModel < ActiveRecord::Base

  #========== ATTRIBUTES

  self.abstract_class = true

  class_attribute :action_view

  # This block allows for models to use methods such as "render" from controllers
  begin
    self.action_view = ActionView::Base.new(Rails.configuration.paths["app/views"])
    self.action_view.class_eval do
      include Rails.application.routes.url_helpers
      include ApplicationHelper

      def protect_against_forgery?
        false
      end
    end
  rescue Exception => e
    throw e
  end

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

  # Allows model to use render function from controllers
  def render(*args)
    action_view.render(*args)
  end

  # Sets default attributes for nil attributes as defined by constant DEFAULT_ATTRIBUTES
  def set_default_attributes_for_nil
    self.class::DEFAULT_ATTRIBUTES.each {|k,v| self.send("#{k.to_s}=".to_sym, v) if self.respond_to?(k) and self.send(k).blank? } if defined? self.class::DEFAULT_ATTRIBUTES
  end

end
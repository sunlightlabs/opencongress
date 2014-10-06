class ActionMailer::Base

  alias_method :original_process, :process

  attr_accessor :_args

  def process(method_name, *args)
    @_args = *args
    original_process(method_name, *args)
  end

end
module AccountHelper

  def confirmation_path (user)
    (user.activation_code.nil? and nil) || url_for(:controller => :account,
                                                   :action => :activate,
                                                   :id => user.activation_code)
  end

end

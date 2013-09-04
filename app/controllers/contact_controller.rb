class ContactController < ApplicationController
  skip_before_filter :has_district?

  def index
  end

  def create
    message = Emailer::feedback(params[:contact]).deliver
    flash[:info] = "Thanks, your feedback was sent!"
    redirect_to "/"
  end

end

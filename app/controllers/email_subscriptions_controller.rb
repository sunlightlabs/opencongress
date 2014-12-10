require 'blue_state_digital'

class EmailSubscriptionsController < ApplicationController
  skip_before_filter :has_district?

  def new
  end

  def create
    response = submit_to_bsd
    if response.code == "302" && response.body =~ /thanks/
      flash[:info] = "Thanks! We'll keep you up to date."
    else
      flash[:error] = "Something went wrong setting your email preferences. You can view them on your profile page."
    end
    redirect_to "/"
  end

  def adhoc
    response = submit_to_bsd
    respond_to do |format|
      if response.code == "302" && response.body =~ /thanks/
        format.json { render :json => {:success => true, :message => "Thanks for subscribing!"}}
        format.text { render :text => "success"}
        format.html { redirect_to "/thanks"}
      else
        flash[:error] = "Oops, your form submission was invalid."
        format.json { render :json => {:success => false}, :status => 400 }
        format.text { render :text => "error", :status => 400 }
        format.html { redirect_to :back}
      end
    end
  end

  protected

  def submit_to_bsd
    if params[:name].present?
      params[:firstname], params[:lastname] = params[:name].split(' ', 2)
    end
    params[:zip] = params[:zipcode] if params[:zipcode].present?
    begin
      result = BlueStateDigital.subscribe_to_email params
    rescue
      ostruct = OpenStruct.new({
        :code => "false",
        :body => "false"
      })
      result = false
    end
    return result == false ? ostruct : result[:response] 
  end
end

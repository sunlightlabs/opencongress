class Admin::HotBillsController < Admin::IndexController
  before_filter :can_blog

  def index
  end
  
  def addbill
    bill = Bill.find_by_id(params[:bill][:id])
    
    if bill
      bill.is_major = (params[:bill][:is_major] == "1")
      bill.plain_language_summary = params[:bill][:plain_language_summary]
      bill.save!
      
      redirect_to bill_path(bill)
    else
      redirect_to home_path
    end
  end
  
end

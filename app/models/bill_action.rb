class BillAction < Action
  belongs_to :bill

  def display
    "<h4>#{bill.title_full_common}</h4>"
  end

  def rss_date
    Time.at(self.date)
  end
  
end


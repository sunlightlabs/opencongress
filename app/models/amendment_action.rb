class AmendmentAction < Action
  belongs_to :amendment
  
  def display
    "<h4>Amendment #{amendment.number}, #{amendment.purpose}, " +
      "#{amendment.status} as of #{amendment.status_datetime}</h4>" +
      "<p>#{amendment.description}</p>" +
      "<p>#{amendment.bill.display}</p>"
  end
end


class ::Date

  DATE_FORMATS[:month_ordinal] = lambda {|date| date.strftime("%A #{date.day.ordinalize}, %B") }

end
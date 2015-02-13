#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'csv'

# Load CSV file and transform data into more palpable form.
file_path = File.join(Settings.data_path, 'bill-nicknames', 'bill-nicknames.csv')
lines = CSV.open(file_path).readlines # get lines
keys = lines.delete(lines.first) # delete labels at top
data = lines.map {|values| Hash[keys.zip(values)] }

# Load each relevant bill and create nickname title if necessary
data.each do |d|
  begin
    bill = Bill.where(session: d['congress'], bill_type: d['bill_type'], number: d['bill_number']).first
    BillTitle.where(bill_id: bill.id, title_type: 'nickname', title: d['term']).first_or_create
  rescue => error
    error.backtrace
  end
end
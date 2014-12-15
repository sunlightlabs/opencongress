#!/usr/bin/env ruby

require 'rubygems'
require 'json'
require 'csv'

# Check if a string should be an integer
#
# @param str [String]
# @return [Bolean] true if int, false otherwise
def is_int?(str)
  !!(str =~ /^[-+]?[1-9]([0-9]*)?$/)
end

file_path = File.join(Settings.unitedstates_data_path, 'bill-nicknames', 'bill-nicknames.csv')
lines = CSV.open(file_path).readlines
keys = lines.delete lines.first

data = lines.map do |values|
  is_int?(values) ? values.to_i : values.to_s
  Hash[keys.zip(values)]
end

data.each do |d|
  bill = Bill.where(session: d['congress'], bill_type: d['bill_type'], number: d['bill_number']).first
  BillTitle.where(bill_id: bill.id, title_type: 'nickname', title: d['term']).first_or_create
end
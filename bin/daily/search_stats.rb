#!/usr/bin/env ruby

term_count = {}

Search.all.each do |search|
  sym = search.search_text.to_sym
  term_count[sym] = 0 unless term_count.has_key?(sym)
  term_count[sym] += 1
end

term_count.each do |k,v|
  ss = SearchStat.where(search_text:k.to_s).first_or_create
  ss.total_searches = v
  ss.save
end
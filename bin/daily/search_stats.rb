#!/usr/bin/env ruby

term_count = {}
today = Date.today

Search.all.each do |search|
  sym = search.search_text.to_sym
  term_count[sym] = {count:0, count_recent:0, first_seen: search.created_at} unless term_count.has_key?(sym)
  term_count[sym][:count] += 1
  term_count[sym][:count_recent] += 1 if (today - search.created_at).to_i <= SearchStat::RECENT_TIMEFRAME
  term_count[sym][:first_seen] = search.created_at unless search.created_at > term_count[sym][:first_seen]
end

term_count.each do |k,v|
  ss = SearchStat.where(search_text:k.to_s).first_or_create
  ss.total_searches = v[:count]
  ss.total_avg_per_day = v[:count].to_f / (today - v[:first_seen]).to_f
  ss.recent_total_searches = v[:count_recent]
  ss.recent_avg_per_day = v[:count_recent].to_f / (today - (today-SearchStat::RECENT_TIMEFRAME.days)).to_f
  ss.save
end
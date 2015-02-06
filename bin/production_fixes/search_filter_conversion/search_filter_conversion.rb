#!/usr/bin/env ruby

# This was a terrible design so I'm fixing this crap with the script below. Basically
# the database was storing integer values to conserve space. This really isn't that
# necessary and just adds layers of confusion. The database will now just store "bills", "people", etc
# serialized as an Array. Below will convert the existing entries in the database to the new format.

SEARCH_FILTERS = {
    0 => :search_bills,
    1 => :search_people,
    2 => :search_committees,
    3 => :search_industries,
    4 => :search_issues,
    5 => :search_news,
    6 => :search_blogs,
    7 => :search_commentary,
    8 => :search_comments,
    9 => :search_gossip_blog
}

Search.where.not(search_filters:nil).each do |search|

    new_filter = search.search_filters.map{|f| f.to_s.gsub('search_','')}

    if (new_filter & Search::SEARCH_FILTERS.map{|f| f.to_s}).size != new_filter.size
      search.search_filters = search.search_filters.map{|f| SEARCH_FILTERS[f.match(/\p{N}/).to_s.to_i].to_s}
      search.save
    end

end
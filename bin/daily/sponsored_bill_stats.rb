#!/usr/bin/env ruby

# Calculate various stats for a person
#
# @param p [Person] person to calculate stats for
# @return [Boolean] true if successful save, throw error otherwise
def do_stats_for_person(p)
  begin
    p.build_person_stats if p.person_stats.nil?
    stats = p.person_stats

    stats.sponsored_bills = p.bills.count
    stats.cosponsored_bills = p.bills_cosponsored.count
    stats.sponsored_bills_passed = p.sponsored_bills_passed.count
    stats.cosponsored_bills_passed = p.cosponsored_bills_passed.count
    stats.abstains_percentage = p.abstains_percentage
    stats.abstains = p.abstained_roll_calls.count
    stats.unabstains = p.unabstained_roll_calls.count
    stats.party_votes_count = %w(Democrat Republican).include?(p.party) ? p.party_votes.count : 0.0
    stats.party_votes_percentage = %w(Democrat Republican).include?(p.party) ? p.with_party_percentage : 0.0

    stats.save
  rescue
    puts "Unable to calculate stats for #{p}."
  end
end

# Calculate the rank of people for given method
#
# @param people [Array<People>] array of Person models
# @param method [String] comparison method: sponsored_bills, cosponsored_bills, etc, etc
def calculate_rank(people, method)
  previous_count = -1.0 ; current_rank = -1
  people.each.with_index(1) do |person, i|
    if previous_count != person.person_stats.send(method)
      current_rank = i
      previous_count = person.person_stats.send(method)
    end

    puts "#{person.name}: SC: #{person.person_stats.send(method)}; Rank: #{current_rank}"

    person.person_stats.send("#{method}_rank=", current_rank)
    person.person_stats.save
  end
end

puts 'Calculating sponsored bills stats...'
[Person.sen, Person.rep].each do |people|

  total = people.size
  people.each.with_index(1) do |p,i|
    puts "Calculating sponsored bills stats for #{p.name} (#{i}/#{total})"
    do_stats_for_person(p)
  end

end

%w(sen rep).each do |p_type|
  joined_people = Person.send(p_type.to_sym).includes(:person_stats).to_a

  puts joined_people.inspect

  %w(sponsored_bills cosponsored_bills sponsored_bills_passed cosponsored_bills_passed).each do |method|
    joined_people.sort! {|a,b| b.person_stats.send(method) <=> a.person_stats.send(method) }
    calculate_rank(joined_people, method)
  end

  joined_people_2 = joined_people.select {|g| !g.person_stats.party_votes_percentage.nil? }.flatten.sort { |a,b| b.person_stats.party_votes_percentage <=> a.person_stats.party_votes_percentage }
  calculate_rank(joined_people_2, 'party_votes_percentage')
  joined_people_2 = joined_people.select {|g| !g.person_stats.abstains_percentage.nil? }.sort { |a,b| b.person_stats.abstains_percentage <=> a.person_stats.abstains_percentage }
  calculate_rank(joined_people_2, 'abstains_percentage')

end
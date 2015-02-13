# == Schema Information
#
# Table name: person_stats
#
#  person_id                               :integer          not null, primary key
#  entered_top_viewed                      :datetime
#  votes_most_often_with_id                :integer
#  votes_least_often_with_id               :integer
#  opposing_party_votes_most_often_with_id :integer
#  same_party_votes_least_often_with_id    :integer
#  entered_top_news                        :datetime
#  entered_top_blog                        :datetime
#  sponsored_bills                         :integer
#  cosponsored_bills                       :integer
#  sponsored_bills_passed                  :integer
#  cosponsored_bills_passed                :integer
#  sponsored_bills_rank                    :integer
#  cosponsored_bills_rank                  :integer
#  sponsored_bills_passed_rank             :integer
#  cosponsored_bills_passed_rank           :integer
#  party_votes_percentage                  :float
#  party_votes_percentage_rank             :integer
#  abstains_percentage                     :float
#  abstains                                :integer
#  abstains_percentage_rank                :integer
#  unabstains                              :integer
#  unabstains_rank                         :integer
#  party_votes_count                       :integer
#

class PersonStats < OpenCongressModel

  #========== ATTRIBUTES

  self.primary_key = 'person_id'

  #========== RELATIONS

  #----- BELONGS_TO
  
  belongs_to :person
  
  belongs_to :votes_most_often_with, :class_name => 'Person', :foreign_key => 'votes_most_often_with_id'
  belongs_to :votes_least_often_with, :class_name => 'Person', :foreign_key => 'votes_least_often_with_id'
  belongs_to :opposing_party_votes_most_often_with, :class_name => 'Person', :foreign_key => 'opposing_party_votes_most_often_with_id'
  belongs_to :same_party_votes_least_often_with, :class_name => 'Person', :foreign_key => 'same_party_votes_least_often_with_id'

  #========== METHODS

  #----- CLASS

  # Calculates all the stats for all current members of congress
  def self.calculate_all_stats
    update_calculations
    update_ranks
  end

  # Calculates all the stats for sponsored bills, party_votes_percentage, etc
  def self.update_calculations
    puts 'Calculating sponsored bills stats...'
    [Person.sen, Person.rep].each do |people|
      total = people.size
      people.each.with_index(1) do |person,i|
        puts "Calculating sponsored bills stats for #{person.name} (#{i}/#{total})"
        person.calculate_stats
      end
    end
  end

  # Iterates over the rank attributes and calls the update method if the method exists
  def self.update_ranks
    [Person.sen, Person.rep].each do |people|
      people_ips = people.includes(:person_stats)
      column_names.select{|attr| attr.include?('_rank')}.each do |name|
        # get the attribute name of the raw value to be ranked
        method = name.gsub('_rank','')
        # get the people with non-nil values for the value and sort them highest to lowest
        sorted_people = people_ips.select{|g| g.person_stats.send(method).present? }.sort {|a,b| b.person_stats.send(method) <=> a.person_stats.send(method) }
        sorted_people.each.with_index(1) do |person, i|
          puts "#{person.name}: SC: #{person.person_stats.send(method)}; Rank: #{i}"
          person.person_stats.send("#{name}=", i)
          person.person_stats.save
        end
      end
    end
  end

  #----- INSTANCE

  public

  # Gets the full name of the person who has this stats
  #
  # @return [String] full name of legislator
  def full_name
    "#{firstname} #{lastname}"
  end

  # Gets the full name prepended by the title of the person who has this stats
  #
  # @return [String] full name of legislator prepended by title
  def title_full_name
		"#{title} " + full_name
  end

  # Calculate various stats for a person
  #
  # @return [Boolean] true if successful save, throw error otherwise
  def update_calculations
    begin
      self.sponsored_bills = person.bills.count
      self.cosponsored_bills = person.bills_cosponsored.count
      self.sponsored_bills_passed = person.sponsored_bills_passed.count
      self.cosponsored_bills_passed = person.cosponsored_bills_passed.count
      self.abstains_percentage = person.abstains_percentage
      self.abstains = person.abstained_roll_calls.count
      self.unabstains = person.unabstained_roll_calls.count
      self.party_votes_count = %w(Democrat Republican).include?(person.party) ? person.party_votes.count : 0.0
      self.party_votes_percentage = %w(Democrat Republican).include?(person.party) ? person.with_party_percentage : 0.0
      self.save
    rescue
      puts "Unable to calculate stats for #{person}."
    end
  end

end
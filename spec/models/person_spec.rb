# == Schema Information
#
# Table name: people
#
#  id                        :integer          not null, primary key
#  firstname                 :string(255)
#  middlename                :string(255)
#  lastname                  :string(255)
#  nickname                  :string(255)
#  birthday                  :date
#  gender                    :string(1)
#  religion                  :string(255)
#  url                       :string(255)
#  party                     :string(255)
#  osid                      :string(255)
#  bioguideid                :string(255)
#  title                     :string(255)
#  state                     :string(255)
#  district                  :string(255)
#  name                      :string(255)
#  email                     :string(255)
#  fti_names                 :tsvector
#  user_approval             :float            default(5.0)
#  biography                 :text
#  unaccented_name           :string(255)
#  metavid_id                :string(255)
#  youtube_id                :string(255)
#  website                   :string(255)
#  congress_office           :string(255)
#  phone                     :string(255)
#  fax                       :string(255)
#  contact_webform           :string(255)
#  watchdog_id               :string(255)
#  page_views_count          :integer
#  news_article_count        :integer          default(0)
#  blog_article_count        :integer          default(0)
#  total_session_votes       :integer
#  votes_democratic_position :integer
#  votes_republican_position :integer
#  govtrack_id               :integer
#  fec_id                    :string(255)
#  thomas_id                 :string(255)
#  cspan_id                  :integer
#  lis_id                    :string(255)
#  death_date                :date
#  twitter_id                :string(255)
#

require 'spec_helper'

describe Person do
  before(:all) do
    # make sample legislators
    ["Republican", "Democrat", "Independent"].each do |party|
      #in office
      [:representative, :senator].each do |chamber|
        FactoryGirl.create(chamber, {
            :party => party,
            :state => "CO"
          })
      end
      # retired 
      FactoryGirl.create(:retired, {
        :firstname => "retiredperson",
        :party => party
      })
    end
  end
  describe "scopes" do
    it "#party should filter by party" do
      republicans = Person.party("Republican").map(&:party).uniq
      expect(republicans.first).to  eq("Republican")
      democrats =  Person.party("Democrat").map(&:party).uniq
      expect(democrats.first).to eq("Democrat")
      independents = Person.party("Independent").map(&:party).uniq
      expect(independents).not_to include("Democrat", "Republican")
    end
    it "#in_state should filter by states" do
      colorado_people = Person.in_state('CO')
      expect(colorado_people.map(&:state).uniq).to eq(["CO"])
    end
    it "#for_congress should return all members associated with a Congress" do
      #create nth_congress so we can check for session
      FactoryGirl.create(:nth_congress, {number: Settings.default_congress})
      congress_num = Settings.default_congress

      @people = Person.for_congress(congress_num)
      member_status = @people.each.map do |p|
        expect(p.roles.first.member_of_congress?(congress_num)).to eq(true)
      end
    end

    it "#for_congress should return members that retired mid_congress" do
      #create nth_congress so we can check for session
      FactoryGirl.create(:nth_congress, {number: Settings.default_congress})
      congress_num = Settings.default_congress

      left_mid_congress = FactoryGirl.create(:left_mid_congress)
      @people = expect(Person.for_congress(Settings.default_congress).map(&:bioguideid)).to include(left_mid_congress.bioguideid)
    end

    it "#chamber should return all members that have served in a chamber" do
      retired = FactoryGirl.create(:retired)
      senator = FactoryGirl.create(:senator)
      rep = FactoryGirl.create(:representative)
      all_house_ever = Person.chamber("rep").map(&:bioguideid)
      expect(all_house_ever).to include(retired.bioguideid)
      expect(all_house_ever).to include(rep.bioguideid)      
      expect(all_house_ever).not_to include(senator.bioguideid) 
    end
    
    it "#committee should return members that are on a specific committee" do
      ["CMT1", "CMT2"].each do |committee_id|
        expect(Person.committee(committee_id)).to eq([])
        committee_member = FactoryGirl.create(:representative)
        committee = FactoryGirl.create(:committee, {:thomas_id => committee_id})
        committee_member.committee_people << FactoryGirl.create(:committee_person, {session: Settings.default_congress, committee_id: committee.id })
        members = Person.committee(committee_id)
        expect(members.map(&:bioguideid)).to include(committee_member.bioguideid)
        expect(members.length).to eq(1)
      end
    end

    it "#state_order should sort members by state" do
      FactoryGirl.create(:retired, {state: "TX"})
      FactoryGirl.create(:retired, {state: "AZ"})      
      sorted_people_states = Person.state_order("DESC").map do |p|
        p.latest_role.state
      end
      current_elected_states_reversed = Person.all.map do |p|
        p.latest_role.state
      end.sort.reverse

      expect(sorted_people_states).to eq(current_elected_states_reversed)
    end

    it "#alphabetical_order should sort members by last name" do
      FactoryGirl.create(:representative, {:lastname => "Aardvark"})
      FactoryGirl.create(:representative, {:lastname => "Zzip"})
      sorted_people_lastnames = Person.alphabetical_order("DESC").map(&:lastname)
      current_people_lastnames = Person.all.map(&:lastname).sort.reverse
      expect(sorted_people_lastnames).to eq(current_people_lastnames)
    end

    it "#party_order should sort members by party" do
      sorted_people_parties = Person.party_order("DESC").map do |p|
        p.roles.first.party
      end
      current_people_parties_sorted = Person.all.map do |p|
        p.roles.first.party
      end.sort.reverse
      expect(sorted_people_parties).to eq(current_people_parties_sorted)
    end
    it "#time_in_office_order should sort members by total years of service as a federal legislator, irrespective of their terms' consecutiveness" do    
      pending("implementation")
      senior_sen = FactoryGirl.create(:senator)
      junior_sen = FactoryGirl.create(:senator)
      (1..6).each do |i|
        starting_congress = Settings.default_congress - (3*i) 
        senior_sen.roles << FactoryGirl.create(:role, {
          :role_type => "sen",
          :startdate =>  NthCongress.start_datetime(starting_congress),
          :enddate => NthCongress.end_datetime(starting_congress + 6)
        })
      end
      expect(Person.time_in_office_order("desc")).to eq("some value")
    end
  end
  describe "roll call votes" do
    it "should filter roll call votes by party" do
      # NthCongress.create(number: 113, start_date: "2013-01-03", end_date: Time.now)
      # vote_with_party = FactoryGirl.create(:roll_call_vote, :republican_voting_with_party)
      
      # expect(vote_with_party.person.party_votes.count).to eq(1)
      # vote_without_party = FactoryGirl.create(:roll_call_vote, :republican_voting_against_party)
      # expect(vote_without_party.person.party_votes.count).to eq(1)
    end
  end
  describe "person identifiers" do
    before(:each) do
      @person = FactoryGirl.create(:representative)
      @person.person_identifiers.create(
        namespace: "fec",
        value: "originalfecid"
      )
    end
    describe "fec_ids" do
      it "should return an array of values" do
        expect(@person.fec_ids.class).to equal(Array)
      end
      it "should return an empty array if no fec ids" do
        new_person = FactoryGirl.create(:representative)
        expect(new_person.fec_ids).to eq([])
      end
    end
    describe "fec_ids=" do
      it "should set ALL associated fec_ids with fec_ids=" do
        @person.fec_ids=["new array", "of values"]
        @person.save
        expect(@person.fec_ids).not_to include("originalfecid")
        expect(@person.fec_ids.count).to eq(2)
      end
    end
    describe "add_fec_id" do
    it "should nondestructively add ids to existing array" do
        person = FactoryGirl.create(:representative)
        person.fec_ids = ["this_is_an_fec_id"]
        person.add_fec_id("this_too")
        expect(person.fec_ids).to include("this_is_an_fec_id")
        expect(person.fec_ids).to include("this_too")
      end
      it "should not add duplicate ids" do
        person = FactoryGirl.create(:representative)
        person.fec_ids = ["this_is_an_fec_id"]
        person.add_fec_id("this_is_an_fec_id")
        expect(person.fec_ids.count).to eq(1)
      end
    end
  end
end

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
#  fti_names                 :public.tsvector
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
  describe "scopes" do
    it "should filter for democrats, republicans, and independents" do
      republicans = Person.republican.map(&:party).uniq
      expect(republicans.first).to  eq("Republican")
      democrats = Person.democrat.map(&:party).uniq
      expect(democrats.first).to eq("Democrat")
      independents = Person.independent.map(&:party).uniq
      expect(independents).not_to include("Democrat", "Republican")
    end
    it "should filter by states" do
      colorado_people = Person.in_state('CO')
      expect(colorado_people.map(&:state).uniq).to eq(["CO"])
    end
  end
  describe "roll call votes" do
    it "should filter roll call votes by party" do
      vote_with_party = FactoryGirl.create(:roll_call_vote, :republican_voting_with_party)
      expect(vote_with_party.person.party_votes.count).to eq(1)
      vote_without_party = FactoryGirl.create(:roll_call_vote, :republican_voting_against_party)
      expect(vote_without_party.person.party_votes.count).to eq(1)
    end
  end
  describe "person identifiers" do
    before(:each) do
      @person = people(:person_226043605)
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
        expect(people(:person_412493).fec_ids).to eq([])
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
        person = people(:person_412493)
        person.fec_ids = ["this_is_an_fec_id"]
        person.add_fec_id("this_too")
        expect(person.fec_ids).to include("this_is_an_fec_id")
        expect(person.fec_ids).to include("this_too")
      end
      it "should not add duplicate ids" do
        person = people(:person_412330)
        person.fec_ids = ["this_is_an_fec_id"]
        person.add_fec_id("this_is_an_fec_id")
        expect(person.fec_ids.count).to eq(1)
      end
    end
  end
end

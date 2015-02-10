require 'spec_helper'

describe PeopleController, type: :controller do
  before(:each) do
    #create 114th Congress
    FactoryGirl.create(:nth_congress, {:number => Settings.default_congress})

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
  describe 'GET #index' do
    context 'when user supplies no filtering params' do
      it 'should return _today\'s_ members of Congress (not the current congress)' do
        retired = FactoryGirl.create(:left_mid_congress) #this person quit one day after the congress started

        get :index
        assigns(:people).each do |person|
          expect(person.is_sitting?).to eq(true)
        end
      end
    end
    context 'when user filters by params[:for_congress]' do
      it 'should return _all_ members of that congress, even if they retired' do
        retired = FactoryGirl.create(:left_mid_congress) #this person quit one day after the congress started
        get :index, {
          :for_congress => 114
        }
        expect(assigns(:people).map(&:bioguideid)).to include(retired.bioguideid)
      end
    end
    context 'when user filters via params[:committee]' do
      it 'should only return members of the committee with that THOMAS id' do
        committee_member = FactoryGirl.create(:representative)
        committee = FactoryGirl.create(:committee, {:thomas_id => "WDGT"})
        committee_member.committee_people << FactoryGirl.create(:committee_person, {session: Settings.default_congress, committee_id: committee.id })

        get :index, {
          :committee => "WDGT"
        }

        assigns(:people).each do |person|
          expect(person.committees.map(&:thomas_id)).to include(committee.thomas_id)
        end
      end
    end
    context 'when user filters via params[:party]' do
      it 'should only return current members of that party' do
        get :index, {
          :party => "Republican"
        }
        assigns(:people).each do |person|
          expect(person.roles.first.party).to eq("Republican")
          expect(person.roles.first.member_of_congress?(Settings.default_congress)).to eq(true)
        end
      end
    end
    context 'when user filters via params[:chamber]' do
      it "should only return current members of that chamber" do
        get :index, {
          :chamber => "rep"
        }
        assigns(:people).each do |person|
          expect(person.roles.first.member_of_congress?).to eq(true)
          expect(person.roles.first.role_type).to eq("rep")
        end
      end
    end
    context 'when user sorts via params[:party_order]' do
      it 'should arrange people by party' do
        get :index, {
          :party_order => "DESC"
        }
        parties_sorted_in_controller = assigns(:people).map do |p|
          p.roles.first.party
        end
        expect(parties_sorted_in_controller).to eq(parties_sorted_in_controller.sort.reverse)
      end
    end
    context 'when user sorts via params[:state]' do
      it 'should arrange people by state' do
        get :index, {
          :state_order => "DESC"
        }
        expect(assigns(:people).map(&:state)).to eq(assigns(:people).map(&:state).sort.reverse)
      end
    end
    context 'when user sorts via params[:alphabetical_order]' do
      it 'should arrange people by lastname' do
        get :index, {
          :alphabetical_order => "DESC"
        }
        expect(assigns(:people).map(&:lastname)).to eq(assigns(:people).map(&:lastname).sort.reverse)
      end
    end
  end
end

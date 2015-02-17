require 'spec_helper'

describe BillController, type: :controller do
  describe 'GET #test' do
		let(:person) {FactoryGirl.create(:person)}
		let(:bill) {FactoryGirl.create(:bill, popular_title: "test sponsor bill")}
		let(:co_sponsored_bill) {FactoryGirl.create(:bill, popular_title: "test co-sponsor bill")}
    
    before :each do
      person.bills << bill
      person.bills_cosponsored << co_sponsored_bill
    end

		it "returns only the sponosred bills" do
			get :test, {sponsor_id: person.id, bills: true}
			expect(assigns(:bills)).to eq([bill])
		end

    it 'returns both sponsored and co sponsored bill' do
      get :test, {sponsor_id: person.id, bills: true, bills_cosponsored: true }
      expect(assigns(:bills)).to eq([bill, co_sponsored_bill])
    end

    it "returns sponsored bills if a sponsor_id is passed to the param" do 
      get :test, {sponsor_id: person.id}
      expect(assigns(:bills)).to eq([bill])
    end

    it "returns recently acted on bills if no params is passed" do
      get :test
      expect(assigns(:bills)).to eq([])
    end
  end
end
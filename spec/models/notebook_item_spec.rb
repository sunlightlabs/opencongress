# == Schema Information
#
# Table name: notebook_items
#
#  id                    :integer          not null, primary key
#  political_notebook_id :integer
#  type                  :string(255)
#  url                   :string(255)
#  title                 :string(255)
#  date                  :string(255)
#  source                :string(255)
#  description           :text
#  is_internal           :boolean
#  embed                 :text
#  created_at            :datetime
#  updated_at            :datetime
#  parent_id             :integer
#  size                  :integer
#  width                 :integer
#  height                :integer
#  filename              :string(255)
#  content_type          :string(255)
#  thumbnail             :string(255)
#  notebookable_type     :string(255)
#  notebookable_id       :integer
#  hot_bill_category_id  :integer
#  file_file_name        :string(255)
#  file_content_type     :string(255)
#  file_file_size        :integer
#  file_updated_at       :datetime
#  group_user_id         :integer
#  user_agent            :string(255)
#  ip_address            :string(255)
#  spam                  :boolean
#  censored              :boolean
#  data                  :text
#

require 'spec_helper'

describe NotebookItem do
  before :each do
    VCR.use_cassette "notebook_item" do
      @item = FactoryGirl.create(:notebook_item)
    end
    @item.data = {:key => "value"}
  end
  describe "serialized data column" do
    it "should accept and store a hash" do
      expect(@item.data[:key]).to eq "value"
    end
  end
  describe "url attribute" do
    before :each do 
      @long_url = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
                  "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" \
                  "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" #256 characters
      @item.url = @long_url
    end
    it "should store 255+ char long values in data column" do
      expect { @item.save! }.not_to raise_error
      @item.data[:long_url].should == @long_url
    end
    it "should return data[:long_url] if url attr value is nil" do
      @item.save
      @item.reload.attributes["url"].should == nil
      expect(@item.url).to eq @item.data[:long_url]
    end
  end
end

# == Schema Information
#
# Table name: subjects
#
#  id               :integer          not null, primary key
#  term             :string(255)
#  bill_count       :integer
#  fti_names        :tsvector
#  page_views_count :integer
#  parent_id        :integer
#

require 'spec_helper'

describe Subject do
  describe "bookmarks" do
    it "should connect model to correct bookmark object" do
      VCR.use_cassette "create_user" do
        @user = FactoryGirl.create(:user)
      end
      subject = Subject.new
      bookmark = Bookmark.new(:user => @user)
      subject.bookmarks << bookmark
      expect(subject.bookmarks).to include(bookmark)
    end
  end
end

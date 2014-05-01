# == Schema Information
#
# Table name: bills
#
#  id                     :integer          not null, primary key
#  session                :integer
#  bill_type              :string(7)
#  number                 :integer
#  introduced             :integer
#  sponsor_id             :integer
#  lastaction             :integer
#  rolls                  :string(255)
#  last_vote_date         :integer
#  last_vote_where        :string(255)
#  last_vote_roll         :integer
#  last_speech            :integer
#  pl                     :string(255)
#  topresident_date       :integer
#  topresident_datetime   :date
#  summary                :text
#  plain_language_summary :text
#  hot_bill_category_id   :integer
#  updated                :datetime
#  page_views_count       :integer
#  is_frontpage_hot       :boolean
#  news_article_count     :integer          default(0)
#  blog_article_count     :integer          default(0)
#  caption                :text
#  key_vote_category_id   :integer
#  is_major               :boolean
#  top_subject_id         :integer
#  short_title            :text
#  popular_title          :text
#  official_title         :text
#  manual_title           :text
#

require 'spec_helper'

describe Bill do
  describe "related_articles" do
    # FIXME: These tests are on the wrong model. finds related articles
    # Should test the model method, not Article's acts_as_taggable finders.
    # Leaving because they're useful currently, but this should be revisited.
    let(:bill) { Bill.new }

    before(:each) do
      @article = Article.create!
      @article.tag_list = 'foo,bar,baz'
      @article.save!
    end

    it "finds related articles" do
      bill.stub(:subject_terms).and_return("foo")
      bill.related_articles.should == [@article]
    end

    it "can match on multiple tags" do
      bill.stub(:subject_terms).and_return("foo,bar")
      bill.related_articles.should == [@article]
    end

    it "can match any of a bill's subjects" do
      bill.stub(:subject_terms).and_return("foo,bar,other,another,yet another")
      bill.related_articles.should == [@article]
    end

    it "won't match if there are no matching tags" do
      bill.stub(:subject_terms).and_return("other")
      bill.related_articles.should be_empty
    end

    it "won't match if there are no tags" do
      bill.stub(:subject_terms).and_return("")
      bill.related_articles.should be_empty
    end
  end
end


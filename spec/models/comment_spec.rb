# == Schema Information
#
# Table name: comments
#
#  id                :integer          not null, primary key
#  commentable_id    :integer
#  commentable_type  :string(255)
#  comment           :text
#  user_id           :integer
#  name              :string(255)
#  email             :string(255)
#  homepage          :string(255)
#  created_at        :datetime
#  parent_id         :integer
#  title             :string(255)
#  updated_at        :datetime
#  average_rating    :float            default(5.0)
#  censored          :boolean          default(FALSE)
#  ok                :boolean
#  rgt               :integer
#  lft               :integer
#  root_id           :integer
#  fti_names         :public.tsvector
#  flagged           :boolean          default(FALSE)
#  ip_address        :string(255)
#  plus_score_count  :integer          default(0), not null
#  minus_score_count :integer          default(0), not null
#  spam              :boolean
#  defensio_sig      :string(255)
#  spaminess         :float
#  permalink         :string(255)
#  user_agent        :text
#  referrer          :string(255)
#

require 'spec_helper'
describe Comment do
  describe "spam detection" do
    let(:comment) { Comment.new }

    before(:each) do
      @article = Article.create!
      @user = users(:jdoe)
      comment.commentable = @article
      comment.user = @user
    end
    # TODO: Issues with akismet and the response received from them
    # come back to later.
    
    # it "does not identify good comments as spam" do
    #   VCR.use_cassette("Good comment akismet response") do
    #     comment.comment = "[innocent,0.25] But behind the public pronouncements, American officials described a growing concern, even at the highest levels of the Obama administration and Pentagon, about the challenges of pulling off a troop withdrawal in Afghanistan that hinges on the close mentoring and training of army and police forces."
    #     comment.ip_address = '216.55.6.122'

    #     comment.save
    #     comment.spam.should == false
    #     comment.akismet_response.should == "false"
    #   end
    # end

    # it "does identify spammy comments as spam" do
    #   VCR.use_cassette("Spam comment akismet response") do
    #     @user.login = 'viagra-test-123'
    #     @user.save
    #     comment.comment = '[spam,0.85] <a href="http://www.kigtropin-shop.com/Wholesale-hgh_c6">HGH</a> <a href="http://www.kigtropin-shop.com/Wholesale-jintropin_c1">Jintropin</a> <a href="http://www.kigtropin-shop.com/Wholesale-hygetropin_c3">Hygetropin</a> <a href="http://www.kigtropin-shop.com/Wholesale-kigtropin_c4">Kigtropin</a> <a href="http://www.kigtropin-shop.com/Wholesale-jintropin-aq_c2">Jintropin AQ</a> <a href="http://www.kigtropin-shop.com/Wholesale-hcg_c7">HCG</a>'
    #     comment.ip_address = '127.0.0.1'

    #     comment.save

    #     comment.spam.should == true
    #     comment.akismet_response.should == "true"
    #   end
    # end
  end
end

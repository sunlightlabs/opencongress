require 'spec_helper'

describe Comment do
  describe "spam detection" do
    let(:comment) { Comment.new }

    before(:each) do
      @article = Article.create!

      @user = User.new(
        :login => 'commenttest',
        :password => 'generic',
        :password_confirmation => 'generic',
        :email => "commenttest@opencongress.org",
        :zipcode => '90039',
        :enabled => true,
        :status => 1,
        :accept_tos => true
      )
      @user.accepted_tos_at = Time.now

      @user.save

      @user.activate!

      comment.commentable = @article
      comment.user = @user
    end

    it "does not identify good comments as spam", :vcr do
      comment.comment = "[innocent,0.25] But behind the public pronouncements, American officials described a growing concern, even at the highest levels of the Obama administration and Pentagon, about the challenges of pulling off a troop withdrawal in Afghanistan that hinges on the close mentoring and training of army and police forces."
      comment.ip_address = '216.55.6.122'

      comment.save

      comment.spam.should == false
      comment.akismet_response.should == "false"
    end

    it "does identify spammy comments as spam", :vcr do
      @user.login = 'viagra-test-123'
      @user.save
      comment.comment = '[spam,0.85] <a href="http://www.kigtropin-shop.com/Wholesale-hgh_c6">HGH</a> <a href="http://www.kigtropin-shop.com/Wholesale-jintropin_c1">Jintropin</a> <a href="http://www.kigtropin-shop.com/Wholesale-hygetropin_c3">Hygetropin</a> <a href="http://www.kigtropin-shop.com/Wholesale-kigtropin_c4">Kigtropin</a> <a href="http://www.kigtropin-shop.com/Wholesale-jintropin-aq_c2">Jintropin AQ</a> <a href="http://www.kigtropin-shop.com/Wholesale-hcg_c7">HCG</a>'
      comment.ip_address = '127.0.0.1'

      puts comment.spam?
      puts comment.akismet_response

      comment.save

      comment.spam.should == true
      comment.akismet_response.should == "true"
    end
  end
end
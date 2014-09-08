require 'spec_helper'

describe ContactCongressMailer do
  let(:contact_congress_letter) { double(ContactCongressLetter) }

  before(:each) do
    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  describe 'reply_received_email' do
    it "sends an email" do
      contact_congress_letter.stub(:to_param).and_return('1')
      contact_congress_letter.stub(:user) { FactoryGirl.build(:jdoe) }
      contact_congress_letter.stub(:subject).and_return('letter subject')
      contact_congress_letter.stub(:to_param).and_return('1')
      

      thread = double('thread')
      thread.stub_chain(:formageddon_recipient, :title).and_return('Mr.')
      thread.stub_chain(:formageddon_recipient, :lastname).and_return('Smith')
      
      ContactCongressMailer.reply_received_email(contact_congress_letter, thread).deliver
      @emails.first.subject.should include('Mr. Smith')
      @emails.first.to.should include('jdoe@example.com')
    end
  end
end

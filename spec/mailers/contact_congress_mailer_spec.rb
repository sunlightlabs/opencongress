require 'spec_helper'

describe ContactCongressMailer do
  let(:contact_congress_letter) { double(ContactCongressLetter) }

  before(:each) do
    @emails = ActionMailer::Base.deliveries
    @emails.clear
  end

  describe 'reply_received_email' do
    it "sends an email" do
      allow(contact_congress_letter).to receive_messages(to_param: 1)
      allow(contact_congress_letter).to receive_messages(user: FactoryGirl.build(:jdoe))
      allow(contact_congress_letter).to receive_messages(subject: 'letter subject')
      # contact_congress_letter.stub(:to_param).and_return('1')

      thread = double('thread')
      allow(thread).to receive_message_chain(:formageddon_recipient, :title).and_return('Mr.')
      allow(thread).to receive_message_chain(:formageddon_recipient, :lastname).and_return('Smith')
      
      ContactCongressMailer.reply_received_email(contact_congress_letter, thread).deliver
      expect(@emails.first.subject).to include('Mr. Smith')
      expect(@emails.first.to).to include('jdoe@example.com')
    end
  end
end
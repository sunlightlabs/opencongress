require 'formageddon'

module GetFormageddonRepliesJob
  def self.perform
    puts "---------------------"
    puts Time.now
    puts "---------------------"

    emails_received = 0
    notifications_sent = 0

    Formageddon::IncomingEmailFetcher.fetch do |letter|
      cclft = ContactCongressLettersFormageddonThread.where(["formageddon_thread_id=?", letter.formageddon_thread.id]).first

      emails_received += 1

      if (cclft && cclft.contact_congress_letter.receive_replies? &&
            (letter.subject =~ /E\-News/).nil? &&
            (letter.subject =~ /Newsletter/).nil?)
        notifications_sent += 1
        begin
          incoming_letters_on_chain = letter.formageddon_thread.formageddon_letters.select{|d| d.direction = "TO_SENDER"}.count
        rescue
          incoming_letters_on_chain = 0
        end
        if incoming_letters_on_chain < 4 #assume address has been subscribed to newsletter if > 3
          Rails.logger.info "Sending an email notification to: #{cclft.contact_congress_letter.user.email}"
          ContactCongressMailer.reply_received_email(cclft.contact_congress_letter, letter.formageddon_thread).deliver
        end
      end
    end
    puts "#{emails_received} emails, #{notifications_sent} notifications"
  end
end
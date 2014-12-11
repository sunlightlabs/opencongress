module TestFormageddonJob
  def self.perform(bioguide)
    ActiveRecord::Base.transaction do
      @person = Person.find_by_bioguideid(bioguide)
      @details = defaults_for(bioguide)
      unless @details.nil?
        @details = @details.merge(
          :formageddon_recipient_id => @person.id,
        )
      else
        error_message = "#{bioguide} is not accounted for in /public/formageddon_test_data.json!"
        puts error_message
        Raven.capture_message(error_message)
        return false
      end
      @thread = Formageddon::FormageddonThread.create(@details)
      @thread.formageddon_letters << Formageddon::FormageddonLetter.create(
        :direction => "TO_RECIPIENT",
        :status => "START",
        :subject => "Thank you for listening",
        :message => <<-EOM.strip_heredoc
        Constituent communication is the key to an engaged and healthy democracy.
        Thanks for everything you do!
        EOM
      )
      @letter = @thread.formageddon_letters.first
      @letter.send_letter
      @after_html = @letter.formageddon_delivery_attempts.first.after_browser_state.raw_html rescue nil
      raise ActiveRecord::Rollback
    end

    ContactCongressTest.create!(
      :bioguideid => bioguide,
      :status => @letter.status,
      :values => @thread.to_json(:include => :formageddon_letters),
      :after_browser_state => @after_html
    )
  end

  private

  def self.defaults_for(bioguide)
    @@legislators ||= JSON.parse(File.read("#{Rails.root}/public/formageddon_test_data.json"))
    leg = @@legislators[bioguide]
    return nil if leg.nil?
    inst = Person.find_by_bioguideid(bioguide)
    {
      :formageddon_recipient_type => "Person",
      :sender_first_name => "John",
      :sender_last_name => "Smith",
      :sender_email => "jsmith@example.com",
      :sender_address1 => leg["example_address"],
      :sender_city => leg["example_city"],
      :sender_state => leg["example_state"],
      :sender_zip5 => leg["zip5"],
      :sender_zip4 => leg["zip4"],
      :sender_phone => "202-555-1234",
      :privacy => "PRIVATE",
    }
  end

end
# == Schema Information
#
# Table name: formageddon_contact_steps
#
#  id                         :integer          not null, primary key
#  formageddon_recipient_id   :integer
#  formageddon_recipient_type :string(255)
#  step_number                :integer
#  command                    :string(255)
#  created_at                 :datetime
#  updated_at                 :datetime
#

require 'sexmachine'
require 'full-name-splitter'
require_pluggable_dependency 'app/models/formageddon/formageddon_contact_step', :from => 'formageddon'

class Formageddon::FormageddonContactStep
  ##
  # This is a monkeypatch to force formageddon to send as a fax when it recovers from an error
  #

  @@gender_guesser = SexMachine::Detector.new
  @@prefix_for_gender = {
    :male => 'Mr.',
    :mostly_male => 'Mr.',
    :female => 'Ms.',
    :mostly_female => 'Ms.',
    :andy => nil
  }

  def save_after_error(ex, letter = nil, delivery_attempt = nil, save_states = true)
    @error_msg = "ERROR: #{ex}: #{$@[0..6].join("\n")}"

    unless letter.nil?
      if letter.is_a? Formageddon::FormageddonLetter
        letter.status = @error_msg
        letter.save
      end

      if save_states
        delivery_attempt.result = @error_msg
        delivery_attempt.save
      end
      # Send as a fax instead
      letter.send_fax :error_msg => @error_msg
    end
  end

  def delegate_choice_value(options = {})
    value = options[:default]

    if options[:type] == :issue_area
      text = options[:letter].message rescue ''
      contactable = ContactCongressLettersFormageddonThread.where(
        :formageddon_thread_id => options[:letter].formageddon_thread.id
        ).order(["formageddon_thread_id DESC"]).first.contact_congress_letter.contactable rescue nil
      if contactable.is_a? Bill
        text = (contactable.subjects.map(&:term).join(' ') + " #{text})" rescue text)
        text += " #{contactable.bill_titles.map(&:title).join(' ')}"  rescue ''

        bill = contactable
        version = bill.bill_text_versions.last
        if version
          path = "#{Settings.oc_billtext_path}/#{bill.session}/#{bill.reverse_abbrev_lookup}/#{bill.reverse_abbrev_lookup}#{bill.number}#{version.version}.gen.html-oc"
          text += " #{File.read(path) rescue nil}"
        end
      end
      value = JSON.load(HTTParty.post("#{Settings.formageddon_select_box_delegate_url}",
          :body => { "text" => text, "choices" => options[:option_list]},
          :headers => { "Content-Type" => "application/x-www-form-urlencoded"}
        ).body) rescue nil
      return value || options[:default]

    elsif options[:type] == :title
      thread = options[:letter].formageddon_thread rescue nil
      return value if thread.nil?
      if thread.sender_first_name == thread.sender_last_name
        first, last = FullNameSplitter.split(thread.sender_first_name)
      else
        first, last = [thread.sender_first_name, thread.sender_last_name]
      end
      return @@prefix_for_gender.fetch(@@gender_guesser.get_gender(first.strip), value)

    end
    value
  end

protected

  def detect_gender(name)
    @@detector ||= Sexmachine::Detector.new
    first_name = name.split(/ \-/).first
    @@detector.get_gender(first_name)
  end
end

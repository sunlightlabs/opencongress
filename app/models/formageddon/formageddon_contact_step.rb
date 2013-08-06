# FIXME: This is ugly.
require_dependency File.expand_path(
  'app/models/formageddon/formageddon_contact_step',
  ActiveSupport::Dependencies.plugins_loader.plugin_paths.select{|p| p =~ /formageddon(-[0-9a-f]+)?$/}.first)

class Formageddon::FormageddonContactStep
  ##
  # This is a monkeypatch to force formageddon to send as a fax when it recovers from an error
  #

  def save_after_error(ex, letter = nil, delivery_attempt = nil, save_states = true)
    @error_msg = "ERROR: #{ex}: #{$@[0]}"

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

  def delegate_select_box_value(options = {})
    value = nil
    if options[:type] == :issue_area
      text = options[:letter].message rescue ''
      if contactable.is_a? Bill
        text = (Bill.subjects.map(&:term).join(' ') + " #{text})" rescue text)
        text += " #{Bill.bill_titles.map(&:title).join(' ')}"  rescue ''
        text += " #{Bill.billtext_text}"
        value = JSON.load(HTTParty.post("#{Settings.formageddon_select_box_delegate_url}",
                                        :body => { "text" => text, "choices" => options[:option_list]},
                                        :headers => { "Content-Type" => "application/x-www-form-urlencoded"}
                                       ).body) rescue nil
      end
      value || options[:default]
    end
  end
end

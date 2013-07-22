# FIXME: This is ugly.
require_dependency File.expand_path(
  'app/models/formageddon/formageddon_contact_step',
  ActiveSupport::Dependencies.plugins_loader.plugin_paths.keep_if{|p| p =~ /gems\/formageddon-[0-9a-f]+$/}.first)

class Formageddon::FormageddonContactStep
  ##
  # This is a monkeypatch to force formageddon to send as a fax when it recovers from an error
  #

  def save_after_error(ex, letter = nil, delivery_attempt = nil, save_states = true)
    @error_msg = "ERROR: #{ex}"

    unless letter.nil?
      if letter.kind_of? Formageddon::FormageddonLetter
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
end
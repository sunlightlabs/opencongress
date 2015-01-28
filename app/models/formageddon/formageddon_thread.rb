# FIXME: This is ugly.
require_dependency File.expand_path(
                       'app/models/formageddon/formageddon_thread',
                       ActiveSupport::Dependencies.plugins_loader.plugin_paths.select{|p| p =~ /formageddon(-[0-9a-f]+)?$/}.first)

require_dependency 'renders_templates'

class Formageddon::FormageddonThread

  before_save :lookup_zip4

  def lookup_zip4
    if self.sender_zip4.blank?
      self.sender_zip4 = ZipInferrenceService.zip4_lookup(sender_address1, sender_city, sender_state, sender_zip5)
    end
  end

end
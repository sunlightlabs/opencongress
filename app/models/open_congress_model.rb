class OpenCongressModel < ActiveRecord::Base

  self.abstract_class = true

  # Insures all descendants have been touched so the descendant list
  # is complete
  #
  # @return array of class descendants
  def self.descendants
    Dir[Rails.root.join('app/models/*.rb').to_s].each{|path|
      File.basename(path, '.rb').camelize.constantize
    }
    super
  end

end
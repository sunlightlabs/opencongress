class AddFaxIdToFormageddonLetter < ActiveRecord::Migration
  def self.up
    if defined?(Formageddon)
      add_column :formageddon_letters, :fax_id, :integer
    end
  end

  def self.down
    if defined?(Formageddon)
      remove_column :formageddon_letters, :fax_id
    end
  end
end

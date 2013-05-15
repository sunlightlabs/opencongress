class AddStateAndDistrictToUser < ActiveRecord::Migration
  def self.up
    add_column :users, :state, :string, :limit => 2
    add_column :users, :district, :integer
    # This is going to run for a couple of hours. Welp.
    User.all.each do |u|
      states = YAML.load(u.state_cache) rescue []
      districts = YAML.load(u.district_cache) rescue []
      if states.length == 1
        u.state = states.first
      else
        u.possible_states = states
      end
      if districts.length == 1
        u.district = districts.first.match(/[\w]{2}-([\d]+)/)[1] rescue nil
      else
        u.possible_districts = districts
      end
      u.save
    end
  end

  def self.down
    remove_column :users, :district
    remove_column :users, :state
  end
end

class AddHashIdToBillNextNodes < ActiveRecord::Migration

  def self.up

    change_table :bill_text_nodes do |t|
      t.string :id_hash
    end

  end

  def self.down

    change_table :bill_text_nodes do |t|
      t.remove :id_hash
    end

  end

end
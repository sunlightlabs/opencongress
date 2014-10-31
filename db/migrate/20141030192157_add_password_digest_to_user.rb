class AddPasswordDigestToUser < ActiveRecord::Migration

  def self.up

    change_table :users do |t|
      t.string :password_digest
    end

  end

  def self.down

    change_table :users do |t|
      t.remove :password_digest
    end

  end

end

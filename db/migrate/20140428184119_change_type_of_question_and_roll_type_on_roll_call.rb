class ChangeTypeOfQuestionAndRollTypeOnRollCall < ActiveRecord::Migration
  def self.up
    change_table :roll_calls do |t|
      t.change(:question, :text)
      t.change(:roll_type, :text)
    end
  end

  def self.down
    change_table :roll_calls do |t|
      t.change(:question, :string, :limit => 255)
      t.change(:roll_type, :string, :limit => 255)
    end
  end
end

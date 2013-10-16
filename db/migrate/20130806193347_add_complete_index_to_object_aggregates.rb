class AddCompleteIndexToObjectAggregates < ActiveRecord::Migration
  def self.up
    # add_index :object_aggregates, [:date, :aggregatable_type, :aggregatable_id], :name => 'aggregatable_date_poly_idx'
  end

  def self.down
    # remove_index :object_aggregates, :name => 'aggregatable_date_poly_idx'
  end
end

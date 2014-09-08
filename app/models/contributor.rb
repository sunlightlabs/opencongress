class Contributor < OpenCongressModel
  validates_uniqueness_of :name
  has_many :person_cycle_contributions, :foreign_key => 'top_contributor_id'
end

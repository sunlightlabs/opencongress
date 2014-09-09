# == Schema Information
#
# Table name: v_current_roles
#
#  state_id  :integer
#  role_id   :integer          primary key
#  person_id :integer
#  role_type :string(255)
#

class VCurrentRole < View
  self.primary_key = :role_id
  belongs_to :state
  belongs_to :role
  belongs_to :person
end

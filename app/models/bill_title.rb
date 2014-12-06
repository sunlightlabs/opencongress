# == Schema Information
#
# Table name: bill_titles
#
#  id         :integer          not null, primary key
#  title_type :string(255)
#  as         :string(255)
#  bill_id    :integer
#  title      :text
#  fti_titles :tsvector
#  is_default :boolean          default(FALSE)
#

class BillTitle < OpenCongressModel

  #========== CONSTANTS

  TYPES = %w(short popular official nickname)

  #========== SCOPES

  TYPES.each do |type|
    scope type.to_sym, -> { where(title_type: type) }
  end

  scope :default, -> { where(is_default: true) }

  #========== RELATIONS

  #----- BELONGS TO

  belongs_to :bill

  #========== METHODS

  #----- CLASS

  #----- INSTANCE

end
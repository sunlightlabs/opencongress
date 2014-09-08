# == Schema Information
#
# Table name: bill_titles
#
#  id         :integer          not null, primary key
#  title_type :string(255)
#  as         :string(255)
#  bill_id    :integer
#  title      :text
#  fti_titles :public.tsvector
#  is_default :boolean          default(FALSE)
#

class BillTitle < OpenCongressModel
  belongs_to :bill
end

# == Schema Information
#
# Table name: sidebar_boxes
#
#  id               :integer          not null, primary key
#  image_url        :string(255)
#  box_html         :text
#  sidebarable_id   :integer
#  sidebarable_type :string(255)
#

class SidebarBox < OpenCongressModel
  belongs_to :sidebarable, :polymorphic => true
  
end

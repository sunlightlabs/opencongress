# == Schema Information
#
# Table name: site_text_pages
#
#  id                      :integer          not null, primary key
#  page_params             :string(255)
#  title_tags              :string(255)
#  meta_description        :text
#  meta_keywords           :string(255)
#  title_desc              :text
#  page_text_editable_type :text
#  page_text_editable_id   :integer
#

class SiteTextPage < ActiveRecord::Base
  belongs_to :page_text_editable, :polymorphic => true
end

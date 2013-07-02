class NotebookItem < ActiveRecord::Base
  acts_as_taggable_on :tags
#  alias tag_list= tag_with

  belongs_to :political_notebook
  belongs_to :notebookable, :polymorphic => true
  belongs_to :bill, :foreign_key => "notebookable_id", :conditions => ["notebookable_type = ?", "Bill"]
  belongs_to :hot_bill_category
  belongs_to :group_user, :class_name => "User"

  validate :embed_doesnt_contain_scripts


  # by default, returns zero; to be overridden by child classes
  def count_times_bookmarked
    return 0
  end

  # by default, returns empty array; to be overridden by child classes
  def other_users_bookmarked
    return []
  end

  def atom_id
    "tag:opencongress.org,#{created_at.strftime("%Y-%m-%d")}:/political_notebook_item/#{id}"
  end

  def type_in_words
    type.to_s.gsub('Notebook', '')
  end

  protected

  def embed_doesnt_contain_scripts
    errors.add(:embed, "can't contain script tags") if embed =~ /<script/i
    errors.add(:embed, "can't include onload scripts") if embed =~ /onload=/i
    iframe_count = embed.match(/<iframe/i).length
    src_count = embed.match(/<iframe[^>]*src=/i).length
    valid_src_count = embed.match(/<iframe[^>]*src=("|')https?:\/\/[^>]+("|')/i).length
    errors.add(:embed, "should reference only iframes with a valid url") if iframe_count > valid_src_count || src_count > valid_src_count
    errors.add(:embed, "can't include css behaviors") if embed =~ /<style.*behavior[\s]*:[\s]*('|")/im
  end

end

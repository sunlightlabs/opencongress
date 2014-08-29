# == Schema Information
#
# Table name: groups
#
#  id                       :integer          not null, primary key
#  user_id                  :integer
#  name                     :string(255)
#  description              :text
#  join_type                :string(255)
#  invite_type              :string(255)
#  post_type                :string(255)
#  publicly_visible         :boolean          default(TRUE)
#  website                  :string(255)
#  pvs_category_id          :integer
#  group_image_file_name    :string(255)
#  group_image_content_type :string(255)
#  group_image_file_size    :integer
#  group_image_updated_at   :datetime
#  state_id                 :integer
#  district_id              :integer
#  created_at               :datetime
#  updated_at               :datetime
#  subject_id               :integer
#

class Group < ActiveRecord::Base
  has_attached_file :group_image, :styles => { :medium => "300x300>", :thumb => "100x100>" },
                                  :path => "#{Settings.group_images_path}/:id/:style/:filename",
                                  :url => "#{Settings.group_images_url}/:id/:style/:filename"

  apply_simple_captcha

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_presence_of :user_id

  belongs_to :user
  has_many :group_invites, :dependent => :destroy
  belongs_to :pvs_category
  belongs_to :subject

  has_many :group_members, :dependent => :destroy
  has_many :users, -> { order("users.login ASC") },
           :through => :group_members

  has_many :group_bill_positions, -> { order('group_bill_positions.created_at desc') }, 
           :dependent => :destroy
  has_many :bills, :through => :group_bill_positions

  has_many :comments, :as => :commentable, :dependent => :destroy

  has_one :political_notebook, :dependent => :destroy

  scope :visible, where(:publicly_visible=>true)
  scope :with_name_or_description_containing, lambda { |q| where(["groups.name ILIKE ? OR groups.description ILIKE ?", "%#{q}%", "%#{q}%"]) }
  scope :in_category, lambda { |category_id| where(:pvs_category_id => category_id) }
  scope :in_state, lambda { |state_id| includes(:state, :district => :state).where(["groups.state_id=? OR districts.state_id=?", state_id, state_id])}

  belongs_to :state
  belongs_to :district

  after_save { |record| record.create_political_notebook if record.political_notebook.nil? }

  def to_param
    "#{id}_#{name.gsub(/[^A-Za-z]+/i, '_').gsub(/\s/, '_')}"
  end

  def default_description
    if is_district_group?
      district.default_group_description
    elsif is_state_group?
      state.default_group_description
    elsif is_issue_group?
      subject.default_group_description
    else
      nil
    end
  end

  def reset_description!
    desc = default_description
    unless desc.nil?
      self.description = desc
      save!
    end
  end

  def display_object_name
    'Group'
  end

  def is_issue_group?
    return false if subject.nil?
    subject.default_group == self
  end

  def is_state_group?
    !!state && !district
  end

  def is_district_group?
    !!district
  end

  def active_members
    users.where("group_members.status != 'BOOTED'")
  end

  def owner_or_member?(u)
    is_owner?(u) or is_member?(u)
  end

  def is_owner?(u)
    self.user == u
  end

  def is_member?(u)
    return false if u == :false

    membership = group_members.where(["group_members.user_id=?", u.id]).first
    return false if membership.nil?
    return false if membership.status == 'BOOTED'
    return true
  end

  def membership(u)
    membership = group_members.where(["group_members.user_id=?", u.id]).first
  end

  def can_join?(u)
    return false if u == :false

    membership = group_members.where(["group_members.user_id=?", u.id]).first

    # if they're already a member, they can't join
    return false if membership or u == self.user

    case join_type
    when 'ANYONE', 'REQUEST'
      return (membership.nil? or membership.status != 'BOOTED') ? true  : false
    when 'INVITE_ONLY'
      if membership and membership.status == 'BOOTED'
        return false
      else
        return !group_invites.where(["user_id=?", u.id]).empty?
      end
    end

    return false
  end

  def can_moderate?(u)
    return false if u == :false
    return true if self.user == u

    membership = group_members.where(["group_members.user_id=?", u.id]).first

    return false if membership.nil?
    return true if membership.status == 'MODERATOR'

    return false
  end

  def can_invite?(u)
    return false if u == :false
    return true if self.user == u

    membership = group_members.where(["group_members.user_id=?", u.id]).first

    return false if membership.nil?

    case invite_type
    when 'ANYONE'
      return true
    when 'MODERATOR'
      return true if membership.status == 'MODERATOR'
    end

    return false
  end

  def can_post?(u)
    return false if u == :false
    return true if self.user == u

    membership = group_members.where(["group_members.user_id=?", u.id]).first

    return false if membership.nil?

    case post_type
    when 'ANYONE'
      return true
    when 'MODERATOR'
      return true if membership.status == 'MODERATOR'
    end

    return false
  end

  def unviewed_posts(u, last_view = nil)
    return 0 if u == :false

    membership = group_members.where(["group_members.user_id=?", u.id]).first

    return 0 if membership.nil? or membership.status == 'BOOTED' or political_notebook.nil?

    return political_notebook.notebook_items.where("created_at > ?", last_view.nil? ? membership.last_view : last_view).size
  end

  def bills_supported
    bills.where("group_bill_positions.position='support'")
  end

  def bills_opposed
    bills.where("group_bill_positions.position='oppose'")
  end

  def domain_verified?
    name, email_domain = self.user.email.split(/@/)

    if self.website.blank?
      return false
    else
      web_domain, junk = self.website.gsub(/http:\/\//, '').split(/\//)

      return !web_domain.nil? && (web_domain =~ /^#{email_domain}$/ or web_domain =~ /\.#{email_domain}$/)
    end
  end
end

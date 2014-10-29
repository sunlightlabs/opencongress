# == Schema Information
#
# Table name: comments
#
#  id                :integer          not null, primary key
#  commentable_id    :integer
#  commentable_type  :string(255)
#  comment           :text
#  user_id           :integer
#  name              :string(255)
#  email             :string(255)
#  homepage          :string(255)
#  created_at        :datetime
#  parent_id         :integer
#  title             :string(255)
#  updated_at        :datetime
#  average_rating    :float            default(5.0)
#  censored          :boolean          default(FALSE)
#  ok                :boolean
#  rgt               :integer
#  lft               :integer
#  root_id           :integer
#  fti_names         :public.tsvector
#  flagged           :boolean          default(FALSE)
#  ip_address        :string(255)
#  plus_score_count  :integer          default(0), not null
#  minus_score_count :integer          default(0), not null
#  spam              :boolean
#  defensio_sig      :string(255)
#  spaminess         :float
#  permalink         :string(255)
#  user_agent        :text
#  referrer          :string(255)
#

require_dependency 'spammable'

class Comment < OpenCongressModel

  #========== INCLUDES

  include Spammable
  include PrivacyObject
  acts_as_nested_set :scope => :root
  rakismet_attrs({
    :author => :author_name,
    :author_url => :homepage,
    :author_email => :author_email,
    :content => :comment,
    :user_ip => :ip_address,
    :user_agent => :user_agent,
    :referrer => :referrer
   })
  # apply_simple_captcha

  #========== VALIDATORS

  validates_presence_of :comment, :message => ' : You must enter a comment.'
  validates_length_of :comment, :in => 1..1000,
                      :too_short => ' : Your comment is not verbose enough, write more.',
                      :too_long => ' : Your comment is too verbose, keep it under 1000 characters.'

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :user
  belongs_to :commentable, :polymorphic => true

  with_options :foreign_key => 'commentable_id' do |c|
    c.belongs_to :bill
    c.belongs_to :person
    c.belongs_to :article
    c.belongs_to :committee
    c.belongs_to :subject
    c.belongs_to :upcoming_bill
    c.belongs_to :notebook_note
    c.belongs_to :notebook_link
  end

  #----- HAS_MANY

  has_many :comment_scores

  #========== SCOPES

  scope :uncensored, -> { where(censored: true) }
  scope :users_only, -> { uncensored.where('comments.user_id IS NOT NULL') }
  scope :top, -> { uncensored.includes(:user).order('comments.plus_score_count - comments.minus_score_count DESC') }
  scope :spamy, -> { where('comments.spam = ?', true) }
  scope :spammy, -> { spamy }
  scope :not_spammy, -> { where('comments.spam = ?', false) }
  scope :most_useful, -> { top.limit(3) }

  #========== METHODS

  #----- CLASS

  # Performs a full text search on comments for the input query
  #
  # @param q [String] string to search for in comments
  # @param options [Hash] optional option hash
  # @return [Array<Comments>] comments which contain the query
  def self.full_text_search(q, options = {})
    congresses = options[:congresses].nil? ? [Settings.default_congress] : options[:congresses]

    s_count = Comment.all.count(:joins => "LEFT OUTER JOIN bills ON (bills.id = comments.commentable_id AND comments.commentable_type='Bill')",
                                :conditions => ["(comments.fti_names @@ to_tsquery('english', ?) AND comments.commentable_type='Bill' AND bills.session IN (?)) OR
                                                 (comments.fti_names @@ to_tsquery('english', ?) AND comments.commentable_type != 'Bill') AND
                                                 comments.commentable_type != 'Person'", q, congresses, q])

    options[:page] = 1 unless options.has_key?(:page)

    # Note: This takes (current_page, per_page, total_entries)
    # We need to do this so we can put LIMIT and OFFSET inside the subquery.
    WillPaginate::Collection.create(options[:page], 12, s_count) do |pager|
      # perfom the find.
      # The subquery is here so we don't run ts_headline on all rows, which takes a long long time...
      # See http://www.postgresql.org/docs/8.4/static/textsearch-controls.html
      pager.replace Comment.find_by_sql(["SELECT
          comments.*, ts_headline(comment, ?) as headline
          FROM (SELECT * from comments LEFT OUTER JOIN bills ON (bills.id = comments.commentable_id AND comments.commentable_type='Bill')
          WHERE ((comments.fti_names @@ to_tsquery('english', ?) AND comments.commentable_type='Bill' AND bills.session IN (?)) OR
                 (comments.fti_names @@ to_tsquery('english', ?) AND comments.commentable_type != 'Bill'))
          AND comments.commentable_type != 'Person'
          ORDER BY comments.created_at DESC LIMIT ? OFFSET ?) AS comments", q, q, congresses, q, pager.per_page, pager.offset])
    end
  end

  #----- INSTANCE

  def author_name
    user.nil? ? nil : user.login
  end

  def author_email
    user.nil? ? nil : user.email
  end

  def score_count_sum
    plus_score_count.to_i - minus_score_count.to_i
  end

  def score_count_all
    plus_score_count.to_i + minus_score_count.to_i
  end

  def commentable_link

    return parent.commentable_link if commentable_type.nil?

    case commentable_type
      when 'Person', 'Committee', 'Article'
        {:controller => commentable_type.pluralize.downcase, :action => 'show', :id => commentable.to_param}
      when 'Bill'
        {:controller => 'bill', :action => 'show', :id => commentable.ident}
      when 'Subject'
        {:controller => 'issue', :action => 'show', :id => commentable.to_param}
      when 'BillTextNode'
        {:controller => 'bill', :action => 'text', :id => commentable.bill_text_version.bill.ident,
         :version => commentable.bill_text_version.version, :nid => commentable.nid }
      when 'ContactCongressLetter'
        {:controller => 'contact_congress_letters', :action => 'show', :id => commentable.to_param}
      else
        {:controller => 'index'}
    end

  end

  def comment_warn(admin)
    self.user.comment_warn(self, admin) if self.user.present?
  end

  def page_link

    return self.parent.commentable_link if self.commentable_type.nil?

    obj = Object.const_get(self.commentable_type)
    specific_object = obj.find_by_id(self.commentable_id)

    case commentable_type
      when 'Bill'
        {:controller => 'bill', :action => 'show', :id => specific_object.ident, :goto_comment => self.id}
      when 'Person'
        {:controller => 'people', :action => 'show', :id => specific_object.to_param, :goto_comment => self.id}
      when 'Subject'
        {:controller => 'issue', :action => 'comments', :id => specific_object.to_param, :comment_page => self.page}
      when 'Article'
        {:controller => 'articles', :action => 'view', :id => specific_object.to_param, :goto_comment => self.id}
      when 'Committee'
        {:controller => 'committees', :action => 'show', :id => specific_object.to_param}
      when 'BillTextNode'
        {:controller => 'bill', :action => 'text', :id => specific_object.bill_text_version.bill.ident,
         :version => self.commentable.bill_text_version.version, :nid => self.commentable.nid }
      else
        {:controller => 'index' }
    end

  end

  # /admin is messed up - quick fix by ds
  def page_link_admin
    return self.parent.commentable_link if self.commentable_type.nil?

    obj = Object.const_get(self.commentable_type)
    specific_object = obj.find_by_id(self.commentable_id)
    if self.commentable_type == "Bill"
      return "/bill/#{specific_object.ident}/show?goto_comment=#{self.id}"
    elsif self.commentable_type == "Person"
      return {:controller => 'people', :action => 'comments', :id => specific_object.to_param, :comment_page => self.page}
    elsif self.commentable_type == "Subject"
      return {:controller => 'issue', :action => 'comments', :id => specific_object.to_param, :comment_page => self.page}
    elsif self.commentable_type == "Article"
      return {:controller => 'articles', :action => 'view', :id => specific_object.to_param}
    elsif self.commentable_type == "Committee"
      return {:controller => 'committees', :action => 'show', :id => specific_object.to_param}
    elsif self.commentable_type == "BillTextNode"
      return {:controller => 'bill', :action => 'text', :id => specific_object.bill_text_version.bill.ident,
              :version => self.commentable.bill_text_version.version, :nid => self.commentable.nid }
    else
      return {:controller => 'index' }
    end
  end

  def page
    page_result = Comment.find_by_sql(["select comment_page(id, commentable_id, commentable_type, ?) as page_number from comments where id = ?", Comment.per_page, self.id])[0]
    page_result.present? ? page_result.page_number : 1
  end

  def commentable_title
    return self.parent.commentable_title if self.commentable_type.nil?

    obj = Object.const_get(self.commentable_type)
    specific_object = obj.find_by_id(self.commentable_id)
    if self.commentable_type == "Bill"
      return specific_object.typenumber
    elsif self.commentable_type == "Person"
      return specific_object.name
    elsif self.commentable_type == "Subject"
      return specific_object.term
    elsif self.commentable_type == "Article"
      return specific_object.title
    elsif self.commentable_type == "ContactCongressLetter"
      return "A Letter to Congress RE: #{specific_object.subject}"
    else
      return "A page on OpenCongress"
    end

  end

  def atom_id
    "tag:opencongress.org,#{created_at.strftime("%Y-%m-%d")}:/comment/#{id}"
  end

  # this is simply the standard equality method in active record's base class.  the problem
  # is that acts_as_nested_set overrides this with a comparison method, <=>, that is not very compatible
  # with multiple trees.  it is provided here to override that method.
  def ==(comparison_object)
    comparison_object.equal?(self) ||
    (comparison_object.instance_of?(self.class) &&
    comparison_object.id == id &&
    !comparison_object.new_record?)
  end

end
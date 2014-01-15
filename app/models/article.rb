class Article < ActiveRecord::Base
  acts_as_taggable

  has_many :comments, :as => :commentable
  has_many :article_images
  belongs_to :user
  default_scope :order => 'created_at DESC'

  def self.per_page
    8
  end

  require 'RedCloth'

  def to_param
    title.blank? ? "#{id}" : "#{id}-#{title.gsub(/[^a-z0-9]+/i, '-')}"
  end

  # hack - this is just used for linking in comment pagination
  def display_object_name
    "Articles"
  end

  def ident
    "Article #{id}"
  end

  def atom_id_as_entry
    "tag:opencongress.org,#{created_at.strftime("%Y-%m-%d")}:/article/#{id}"
  end

  def atom_id_as_feed
    "tag:opencongress.org,#{created_at.strftime("%Y-%m-%d")}:/article_feed/#{id}"
  end

  def content_rendered
    return RedCloth.new(self.article).to_html

    if render_type == 'html'
      return self.article
    end
    return markdown(self.article)
  end

  def html_stripped
    article.blank? ? "" : self.article.gsub(/<\/?[^>]*>/, "")
  end

  def excerpt_for_blog_page
    unless excerpt.blank?
      return excerpt
    else
      return "#{html_stripped[0..500]}..."
    end
  end

  def icon
    return case content_type
      when 'archive' then 'icons/page_white_compressed.png'
      when 'mockup' then 'icons/pictures.png'
      else                'icons/page_white_text.png'
      end
  end

  def formatted_date
    created_at.strftime "%B %e, %Y"
  end

  class << self
    def render_types
      ['markdown', 'html']
    end

    def recent_articles(limit = 10, offset = 0)
      Article.find(:all, :conditions => "published_flag = true", :offset => offset, :limit => limit)
    end

    def frontpage_gossip(number = 4)
      Article.find(:all, :limit => number, :conditions => 'frontpage = true')
    end

    def find_by_month_and_year(month, year)
      Article.find(:all, :conditions => [
              "date_part('month', articles.created_at) = ?
              AND date_part('year', articles.created_at) = ?
              AND published_flag = true", month, year],
                   :include => [:user, :comments])
    end

    def archive_months(limit, offset)
      Article.with_exclusive_scope { find(:all, :limit => limit, :offset => offset,
                   :select => "DISTINCT date_part('year', created_at) as year, date_part('month', created_at) as month, to_char(created_at, 'Month YYYY') as display_month",
                   :order => "year desc, month desc, display_month desc") }
    end

  end # class << self
end

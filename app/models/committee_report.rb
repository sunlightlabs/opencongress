class CommitteeReport < ActiveRecord::Base
  validates_uniqueness_of :number,   :scope => [:kind, :congress]
  validates_uniqueness_of :kind,     :scope => [:congress, :number]
  validates_uniqueness_of :congress, :scope => [:number, :kind]
  #validates_uniqueness_of :gpo_id

  belongs_to :bill
  belongs_to :person
  belongs_to :committee

  def to_param
    "#{id}_#{name}"
  end

  def thomas_url
    "http://thomas.loc.gov/cgi-bin/cpquery/T?&report=%s&dbname=%s&" % [name, congress]
  end

  def gpo_url
    "http://www.gpo.gov/fdsys/pkg/#{gpo_id}/content-detail.html"
  end

  def atom_id
    "tag:opencongress.org,#{reported_at.strftime("%Y-%m-%d")}:/committee_report/#{id}"
  end

  def rss_date
    if self.reported_at
      self.reported_at
    else
      nil
    end
  end
end

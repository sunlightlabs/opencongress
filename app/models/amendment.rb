# == Schema Information
#
# Table name: amendments
#
#  id                   :integer          not null, primary key
#  number               :string(255)
#  retreived_date       :integer
#  status               :string(255)
#  status_date          :integer
#  status_datetime      :datetime
#  offered_date         :integer
#  offered_datetime     :datetime
#  bill_id              :integer
#  purpose              :text
#  description          :text
#  updated              :datetime
#  key_vote_category_id :integer
#

class Amendment < ActiveRecord::Base
  belongs_to :bill
  has_many :actions, :class_name => 'AmendmentAction'
  has_many :roll_calls, :order => 'date'
  belongs_to :key_vote_category, :class_name => "PvsCategory", :foreign_key => :key_vote_category_id

  def display_number
    if number.nil? or number.empty?
      ""
    else
      prefix = case number[0]
               when 'h' then 'H.Amdt'
               when 's' then 'S.Amdt'
               end
      "#{prefix} #{number[1..-1]}"
    end
  end
  
  def offered_date_short
    Time.at(offered_date).utc.strftime("%b ") + Time.at(offered_date).utc.day.ordinalize    
  end
  
  def thomas_url
    "http://hdl.loc.gov/loc.uscongress/legislation.#{bill.session}#{number[0...1]}amdt#{number[1..-1]}"
  end

  def ident
    return "#{number.first}amdt#{number[1..-1]}-#{bill.session}"
  end

  def self.ident_pattern
    /([sh]amdt)(\d+)-(\d+)/
  end

  def self.parse_ident (ident_string)
    m = ident_pattern.match(ident_string)
    return nil if m.nil?
    return nil if m.captures.any?(&:nil?)

    chamber_abbrev, number, congress = m.captures
    [chamber_abbrev, number.to_i, congress.to_i]
  end

  def self.find_by_ident (ident_string)
    chamber_abbrev, number, congress = parse_ident(ident_string)
    ch_number = "#{chamber_abbrev.first}#{number}"
    amendments = Amendment.where(:number => ch_number, :congress => congress)
    if amendments.empty?
      raise ActiveRecord::RecordNotFound.new("Couldn't find amendment with ident #{ident_string}")
    elsif amendments.length > 1
      raise Exception.new("Multiple amendments found with ident #{ident_string}")
    else
      amendments.first
    end
  end
end

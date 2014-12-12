# == Schema Information
#
# Table name: bill_text_nodes
#
#  id                   :integer          not null, primary key
#  bill_text_version_id :integer
#  nid                  :string(255)
#

class BillTextNode < OpenCongressModel

  #========== CONSTANTS

  DISPLAY_OBJECT_NAME = 'Bill Text'

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :bill_text_version

  #----- HAS_MANY

  has_many :comments, :as => :commentable

  #========== ACCESSORS
  
  attr_accessor :bill_text_cache

  #========== METHODS

  #----- INSTANCE

  public
  
  def display_object_name
    DISPLAY_OBJECT_NAME
  end

  def ident
    "#{self.bill_text_version_id}-#{self.nid}"
  end

  def paragraph_number
    stuff = nid.split(/:/)
    stuff[2]
  end
  
  def bill_text
    return @bill_text_cache unless @bill_text_cache.nil?
    
    path = "#{Settings.oc_billtext_path}/#{bill_text_version.bill.session}/#{bill_text_version.bill.bill_type}#{bill_text_version.bill.number}#{bill_text_version.version}.gen.html-oc"
    
    begin
      doc = Nokogiri::XML(open(path))    
      node = doc.css("p[@id='bill_text_section_#{nid}']")
      @bill_text_cache = node.text.gsub(/CommentsClose CommentsPermalink/, "")
    rescue
      return ''
    end
  end
end

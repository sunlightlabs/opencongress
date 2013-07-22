# Methods for sending a rendered HTML model as a fax.
# expects the including class to implement an 'as_html' method, returning an HTML string
# also expects a fax_id field on the model

require File.expand_path('../faxable/configuration', __FILE__)
require File.expand_path('../faxable/railtie', __FILE__) if defined? Rails::Railtie

module Faxable
  extend ActiveSupport::Concern

  def send_as_fax(recipient)
    cleaned_number = recipient.gsub('-', '')
    cleaned_number = "1#{cleaned_number}" if cleaned_number.length == 10
    filename = to_pdf
    if Faxable.config.deliver_faxes
      @fax ||= Phaxio.send_fax(:to => cleaned_number, :filename => filename)
      self.update_attribute(:fax_id, @fax['faxId']) rescue nil
    else
      Faxable.logger.info("Suppressing fax: <to: #{cleaned_number}, filename: #{filename}>")
    end
    @file.close if defined?(@file)
  end

  def fax_status
    return nil unless respond_to?(:fax_id) && fax_id.present?
    Phaxio.get_fax_status(:id => fax_id)
  end

  # protected

  def to_pdf
    @kit ||= PDFKit.new(as_html, :page_size => "Letter")
    @file = Tempfile.new(["contact_congress_fax_#{id}", '.pdf'])
    @file.binmode
    @file.write(@kit.to_pdf)
    @file.close
    @file.open
    @file
  end

end

PDFKit.configure do |config|
  config.wkhtmltopdf = `which wkhtmltopdf`.chop
  config.default_options = {
    :page_size => 'Letter',
    :print_media_type => true
  }
  config.root_url = Settings.base_url
end

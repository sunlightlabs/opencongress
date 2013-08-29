PDFKit.configure do |config|
  config.wkhtmltopdf = 'xvfb-run wkhtmltopdf' if `which xvfb-run`
  config.default_options = {
    :page_size => 'Letter',
    :print_media_type => true
  }
  config.root_url = Settings.base_url
end

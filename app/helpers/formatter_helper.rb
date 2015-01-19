module FormatterHelper
  def example_code(lang = 'markup', &block)
      output = capture( &block )
      output = output.strip_heredoc
      output = CGI.escapeHTML(output)
      output = raw(output)

      render partial: 'styleguide/partials/example_code', 
             locals:  { lang: lang, text: output }
  end
end
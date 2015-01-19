module FormatterHelper
  def example_code(&block)
      output = capture( &block )
      output = output.strip_heredoc
      output = CGI.escapeHTML(output)
      output = raw(output)

      render partial: 'styleguide/partials/example_code', 
             locals:  { text: output }
  end
end
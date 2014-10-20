module IndexHelper
  def gossip_excerpt_with_more(text)

    if text.length <= 250
      text
    else
      text_no_html = text.gsub(/<\/?[^>]*>/, "")

      space = text_no_html.index(' ', 250)

      #text.gsub!(/"/, "\\\"")
      #text.gsub!(/'/, "&apos;")

      %Q{<span id="gossip_more"">#{text_no_html[0..space]} <a href="javascript:replace('gossip_extra', 'gossip_more')">continued...</a></span>
      <span id="gossip_extra" style="display: none">#{text}</span>}
    end
  end

  def next_session_nice(date)
    distance = date - Date.today

    case distance
    when 1
      return 'Tomorrow'
    when 2..6
      return date.strftime("%A")
    else
      return date.strftime("%B %d, %Y")
    end
  end

  def homepage_object_count(object, count_type)

    case count_type
    when 'views'
      return "#{number_with_delimiter(object.views)} views"
    when 'news_articles'
      return "#{number_with_delimiter(object.commentary_count('news'))} articles"
    when 'blog_articles'
      return "#{number_with_delimiter(object.commentary_count('blog'))} articles"
    end

    return ""
  end

  def get_result_image(rcall, html_options = {})
    {
      true => image_tag("passed_big.png", {:alt => rcall.result, :title => rcall.result}.merge(html_options)),
      false => image_tag("Failed_big.gif", {:alt => rcall.result, :title => rcall.result}.merge(html_options)),
      nil => content_tag(:span, html_options){rcall.result}.html_safe
    }[rcall.boolean_result]
  end

  def session_div(chamber, session, date=(@updated_at.to_date rescue Date.today))
    out = %Q{<div class="#{chamber}_sesh #{(session and session.for_date?(date)) ? 'in_session' : 'out_session'}"><strong>#{chamber.capitalize}:</strong> }
    if session and session.for_date?(date)
      out += "In Session"
    elsif session
      out += "Returns #{session.date.strftime("%b")}. #{session.date.day.ordinalize}"
    else
      out += "Not In Session"
    end
    out += "</div>"
    out.html_safe
  end

  def recess_div(session)
    return if session.date < Date.today

    %Q{<div class="recess next_recess">#{session.is_in_session ? 'Next Recess' : 'Returns'}: #{session.date.strftime('%B %d')}</div>}
  end

  def session_li(chamber, session, date=(@updated_at.to_date rescue Date.today))
    out = %Q{<li class="#{(session and session.for_date?(date)) ? 'on' : 'off'}"><strong>#{chamber.capitalize}:</strong> }
    if session and session.for_date?(date)
      out += "In Session"
    elsif session
      out += "Returns #{session.date.strftime("%b")}. #{session.date.day.ordinalize}"
    else
      out += "Not In Session"
    end
    out += "</li>"
    out.html_safe
  end
end


# For displaying a block documented with KSS.
#
# section - The name of the section to render.
#
# Returns nothing. Renders a string of HTML to the template.
def kss_block(section, &block)
  @section = @styleguide.section(section)
  
  modifiers = @section.modifiers
  @escaped_html = ERB::Util.html_escape @example_html
  @example_html = html_escape capture(&block)
  concat render(:partial => "styleguide_block", :locals => {
    :html => @example_html,
    :modifiers => modifiers})
end

class Wiki < ActiveRecord::Base
  # This is not in app/models because it's not a real model.
  # But you could subclass this there if you wanted to use wiki tables in Rails.
  # eg. "class Page < Wiki" would use the wiki connection.
  require 'mediacloth'
  require 'hpricot'
  
  begin
    establish_connection :oc_wiki
  rescue ActiveRecord::AdapterNotSpecified
    logger.warn "WARNING: oc_wiki configuration is not specified in database.yml"
  end

  self.table_name = 'text'

  def self.summary_text_for(article_name)
    begin
      a = find_by_sql(['select rev_id, rev_timestamp, t.old_text, p.page_title, p.page_namespace from revision r, page p, text t where r.rev_id = p.page_latest and t.old_id = r.rev_text_id and page_title = ?', article_name])

      return nil if (a.nil? || a.empty?)
    
      # for some reason, newlines were messing up mediacloth
      no_newlines = a[0].old_text.gsub(/\n/, '')
      no_newlines =~ /\{\{Article summary\|(.*?)\}\}/

      if $~[1].blank?
        return nil
      else
        # remove the <ref> tags before returning
        doc = Hpricot(MediaCloth.wiki_to_html($~[1]))                 
        doc.search("ref").remove
                  
        return doc.to_html
      end
    rescue
      return nil
    end
  end
  
  def self.wiki_link_for_bill(session, typenum)    
    begin
      link = find_by_sql(["SELECT smw_title AS wiki_title FROM smw_ids AS sids
                            INNER JOIN
                              (SELECT s_id FROM smw_rels2 INNER JOIN smw_ids AS p ON p_id=p.smw_id INNER JOIN smw_ids AS o ON o_id=o.smw_id 
                               WHERE p.smw_title='Congressnumber' AND o.smw_title=?)
                              AS num_q ON num_q.s_id=sids.smw_id
                            INNER JOIN
                              (SELECT s_id FROM smw_rels2 INNER JOIN smw_ids AS p ON p_id=p.smw_id INNER JOIN smw_ids AS o ON o_id=o.smw_id 
                               WHERE p.smw_title='Billnumber' AND o.smw_title=?)
                              AS bill_q ON bill_q.s_id=sids.smw_id", session, typenum])
      (link.nil? || link.empty?) ? nil : link.first.wiki_title
    rescue
      return nil
    end
  end
  
  def self.biography_text_for(member_name)
    bad_tags = [ 'ACRONYM', 'ADDRESS', 'APPLET', 'AREA', 'BASE', 'BASEFONT',
                 'BDO', 'BODY', 'BUTTON', 'CAPTION', 'CENTER', 'CITE', 'CODE',
                 'COL', 'COLGROUP', 'DD', 'DEL', 'DFN', 'DIR', 'DIV', 'DL',
                 'DT', 'FIELDSET', 'FONT', 'FORM', 'FRAME', 'FRAMESET', 'H1',
                 'H2', 'H3', 'H4', 'H5', 'H6', 'HEAD', 'HR', 'HTML', 'IFRAME',
                 'IMG', 'INPUT', 'INS', 'ISINDEX', 'KBD', 'LABEL', 'LEGEND',
                 'LI', 'LINK', 'MAP', 'MENU', 'META', 'NOFRAMES', 'NOSCRIPT',
                 'OBJECT', 'OL', 'OPTGROUP', 'OPTION', 'PARAM', 'PRE',
                 'Q', 'S', 'SAMP', 'SCRIPT', 'SELECT', 'SMALL', 'SPAN',
                 'STYLE', 'TABLE', 'TBODY', 'TD', 'TEXTAREA', 'TFOOT', 'TH',
                 'THEAD', 'TITLE', 'TR', 'TT', 'UL', 'VAR' ]

    begin
      a = find_by_sql(['select rev_id, rev_timestamp, t.old_text, p.page_title, p.page_namespace from revision r, page p, text t where r.rev_id = p.page_latest and t.old_id = r.rev_text_id and page_title = ?', member_name])

      return nil if (a.nil? || a.empty?)
    
      # for some reason, newlines were messing up mediacloth
      no_newlines = a[0].old_text.gsub(/\n/, '<br/>')   
      no_newlines =~ /==\s*?Bio(graphy)?\s*?==(.*?)==/

      if $~[2].blank?
        return nil
      else
        bio_wiki_text = $~[2]
        # remove the <ref> tags before returning
        doc = Hpricot(MediaCloth.wiki_to_html(bio_wiki_text))
        bad_tags.each do |tag_name|
          tags = doc.search(tag_name.downcase)
          tags.each do |tag|
            tag.swap(tag.innerHTML)
          end
        end
        doc.search("ref").remove

        html = doc.to_html
        # Some wikitext <ref> tags are encoded as html entities. Strip them out.
        html = html.gsub(/\&lt;ref\&gt;.*?\&lt;\/ref\&gt;/, '')

        doc.search('a').each do |anchor|
          html = html.sub(anchor.to_s, anchor.inner_text.sub('w:', ''))
        end

        if Hpricot(html).inner_text.length == 0
          nil
        else
          html
        end
      end
    rescue
      return nil
    end
  rescue Exception => e
    puts e
    return nil
  end

end

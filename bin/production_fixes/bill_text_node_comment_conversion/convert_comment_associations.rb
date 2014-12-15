#!/usr/bin/env ruby

bill = Bill.where(bill_type:'hr',session:113,number:592).first

doc = Nokogiri::XML(bill.full_text)
html = Nokogiri::XML(bill.full_text_as_html)

white = Text::WhiteSimilarity.new

doc.xpath('//*[@nid]').each do |section|

  final_str = ''

  section.children.each do |child|

    if child.name == 'text'
      final_str += child.text
    end

    if child.name == 'span'

      if child['class'] == 'bill_text_changed'
        final_str += child.children[1].children[0].text
      end

      if child['class'] == 'bill_text_inserted'
        final_str += child.children[0].text
      end

    end

  end

  comparison = {}

  html.xpath('//section').each do |node|

    if node['class'] != 'xml_legis-body' and node.attributes.has_key?('data-id')
      text = node.text.to_s.gsub(/\n/,' ').gsub(/\t/,'')
      similarity = white.similarity(final_str.downcase, text.downcase)
      comparison[node] = similarity
    end

  end

  puts 'NID SECTION'
  puts final_str
  puts 'CLOSEST HTML'
  puts comparison.invert[comparison.values.max].text.to_s.gsub(/\n/,' ').gsub(/\t/,'')
  puts 'SIMILARITY'
  puts comparison.values.max

end
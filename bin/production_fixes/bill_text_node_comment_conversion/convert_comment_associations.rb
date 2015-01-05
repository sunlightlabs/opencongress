#!/usr/bin/env ruby

# require 'thread/pool'

# clean slate each run
# BillTextNode.update_all({id_hash: nil})

# text comparison object
$WHITE = Text::WhiteSimilarity.new

# monkey patch custom method for Nokogiri nodes
Nokogiri::XML::Node.class_eval do
  def traverse_conditions(root_node = true, &block)
    if root_node or not (attributes.has_key?('data-id') or attributes.has_key?('id') or attributes.has_key?('id-ref'))
      children.each{|j| j.traverse_conditions(false, &block) }
    end
    block.call(self)
  end
end

def format_string(str)
  str.gsub(/\n/,' ').gsub(/\t/,'').gsub(/(\s+)/,' ')
end

def store_comparison(comparison, node, text, final_str)
  similarity = $WHITE.similarity(final_str.downcase.strip_punctuation, text.downcase.strip_punctuation)
  comparison[node] = similarity unless comparison.has_key?(node) and comparison[node] > similarity
end

def parse_and_compare(bill, version, btn)

  begin

    # get text and parse it with nokogiri
    bill_doc = bill.full_text(version)
    bill_html = bill.full_text_as_html(version)
    doc = Nokogiri::XML(bill_doc)
    html = Nokogiri::XML(bill_html)

    unless bill_doc.blank? or bill_html.blank?

      # find all tags with an nid and iterate over them
      doc.xpath("//*[@nid='#{btn.nid.to_s}']").each do |section|

        # reconstruct string in the nid from the children
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

        # hash to map comparison string to similarity value
        comparison = {}

        # check the official title first
        html.xpath("//p[@class='xml_official-title']").each do |node|
          store_comparison(comparison, node, format_string(node.text.to_s), final_str)
        end

        # check each section individually
        html.xpath('//section').each do |node|
          if node['class'] != 'xml_legis-body' and node.attributes.has_key?('data-id')
            store_comparison(comparison, node, format_string(node.text.to_s), final_str)
          end
        end

        # if the official title no individual sections deliver a high enough similarity
        unless comparison.values.collect{|val| val > 0.9}.any?

          html.xpath('//section').each do |node|

            # individual children nodes
            node.traverse_conditions do |node_child|
              unless node_child.attributes.has_key?('data-id') or node_child.attributes.has_key?('id') or node_child.attributes.has_key?('id-ref')
                store_comparison(comparison, node, format_string(node_child.text.to_s), final_str)
              end
            end

            # progressively more node text from children
            text = ''
            node.traverse_conditions do |node_child|
              unless node_child.attributes.has_key?('data-id') or node_child.attributes.has_key?('id') or node_child.attributes.has_key?('id-ref')
                text += format_string(node_child.text.to_s)
                store_comparison(comparison, node, text, final_str)
              end
            end

          end

        end

        puts 'NID SECTION'
        puts final_str
        puts 'CLOSEST HTML'
        highest = comparison.values.max
        best_node = comparison.invert[highest]
        puts best_node.text.to_s
        puts 'SIMILARITY'
        puts comparison.values.max
        threshold = final_str.size < 100 ? 0.70 : 0.85
        if highest > threshold
          puts 'Updating id_hash...'
          if best_node.attributes.has_key?('data-id')
            btn.update_attribute(:id_hash, best_node['data-id'])
          else
            btn.update_attribute(:id_hash, 'official-title')
          end

        end

      end

    else
      puts "United States Bill XML missing for #{bill.id} in #{bill.session} session"
    end

  rescue Exception => ex
    puts ex.message
    puts ex.backtrace.join("\n")
  end

end

def migrate(bill_id = nil)
  if bill_id.nil?
    # Iterate over every comment on BillTextNodes
    Comment.where(commentable_type:'BillTextNode').each do |comment|
      # get relevant models
      btn = BillTextNode.find(comment.commentable_id)
      btv = BillTextVersion.find(btn.bill_text_version_id)
      bill = Bill.find(btv.bill_id)
      version = btv.version
      if btn.id_hash.nil?
        parse_and_compare(bill, version, btn)
      else
        puts 'skipping...'
      end
    end
  else
    BillTextNode.where(id_hash: nil).find_each(batch_size: 1) do |btn|
      version = btn.bill_text_version
      bill = version.bill
      comment = Comment.where(commentable_type:'BillTextNode', commentable_id: btn.id).count
      if comment > 0
        parse_and_compare(bill, version.version, btn)
        GC.start
      end
    end
  end
end

migrate()

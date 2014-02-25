require 'rexml/document'
require 'ostruct'
require 'date'
require 'yaml'
require 'fileutils'


module ParseBillTextJob
  include REXML

  def self.perform (options = {})
    congress = options.fetch(:congress, Settings.default_congress).to_i

    Bill.get_types_ordered_new.each do |bill_type, bill_title_prefix|
      # We get the bill list from the database because even if we have a
      # text file for a bill, we won't ever display it unless it's also
      # in the database.
      bill_list = Bill.where(:bill_type => bill_type, :session => congress).order(:number).to_a

      # Keep a file listing around to avoid globing the directory for each file.
      bill_version_file_lookup = build_version_file_lookup(congress, bill_type)
      bill_text_file_lookup = build_text_file_lookup(congress, bill_type)

      puts "Processing #{bill_list.length} bills of type #{bill_type}"
      bill_list.each do |bill|
        version_files = bill_version_file_lookup.fetch(bill.ident, [])
        text_files = bill_text_file_lookup.fetch(bill.ident, [])
        parse_files bill, text_files, version_files, options
      end
    end
  end

  def self.version_file_pattern (bill_type)
    /.*(#{bill_type}[0-9]+)_([a-z]+)-([a-z]+)\.xml$/
  end

  def self.text_file_pattern (bill_type)
    /.*(#{bill_type}[0-9]+)([a-z]+)\.gen\.html$/
  end

  def self.processed_text_file_path (bill, version)
    File.join(Settings.oc_billtext_path,
              bill.session.to_s,
              bill.reverse_abbrev_lookup,
              "#{bill.reverse_abbrev_lookup}#{bill.number}#{version}.gen.html-oc")
  end

  def self.parse_files (bill, text_files, version_files, options = {})
    # For bills with version files, we use the "from-to" file as the text of
    # the "to" version of the bill. There will be no such version for the
    # initial version, so we use the text file for that version.
    to_versions = version_files.map{ |ver| ver[:to_version] }
    text_versions = text_files.map{ |txt| txt[:version] }
    initial_versions = text_versions - to_versions
    puts "Parsing files for #{bill.ident} :: #{initial_versions} :: #{to_versions}"

    text_files.each do |txt|
      if initial_versions.include?(txt[:version])
        input_path = txt[:path]
        output_path = processed_text_file_path(bill, txt[:version])
        parse_file(bill, txt[:version], input_path, output_path, options)
      end
    end

    version_file_groups = version_files.group_by{ |ver| ver[:to_version] }
    version_file_groups.each do |to_version, versions|
      unless initial_versions.include?(to_version)
        # The site allows the user to select a version and show the changes between the
        # initial version and the selected version. Here we try to pull out the file that
        # includes the differences between the initial version and this version. If no
        # such file exists we log a warning since this should never happen.
        from_initial = versions.select{ |v| initial_versions.include?(v[:from_version]) }.first
        if from_initial.nil?
          OCLogger.log "Warning: No #{initial_versions} -> #{to_version} for #{bill.ident}"
        else
          OCLogger.log "Choosing #{from_initial[:from_version]} -> #{to_version} for #{bill.ident}"
          input_path = from_initial[:path]
          output_path = processed_text_file_path(bill, from_initial[:to_version])
          parse_file(bill, to_version, input_path, output_path, options)
        end
      end
    end
  end

  # TODO: Should be private
  def self.build_version_file_lookup (congress, bill_type)
    govtrack_bill_type = Bill.govtrack_lookup(bill_type)
    version_dir = File.join(Settings.govtrack_billtext_diff_path, congress.to_s, govtrack_bill_type)
    version_files = Dir.glob(File.join(version_dir, "#{govtrack_bill_type}*.xml"))
    fnpattern = version_file_pattern(govtrack_bill_type)

    versions = version_files.map do |path|
      m = fnpattern.match(path)
      m && {
        :path => path,
        :from_version => m.captures[1],
        :to_version => m.captures[2],
        :bill_ident => "#{m.captures[0]}-#{congress}"
      }
    end

    versions.group_by do |ver|
      ver && ver[:bill_ident]
    end
  end

  def self.build_text_file_lookup (congress, bill_type)
    govtrack_bill_type = Bill.govtrack_lookup(bill_type)
    text_dir = File.join(Settings.govtrack_billtext_path, congress.to_s, govtrack_bill_type)
    text_files = Dir.glob(File.join(text_dir, "#{govtrack_bill_type}*.gen.html"))
    fnpattern = text_file_pattern(govtrack_bill_type)

    texts = text_files.map do |path|
      m = fnpattern.match(path)
      m && {
        :path => path,
        :version => m.captures[1],
        :bill_ident => "#{m.captures[0]}-#{congress}"
      }
    end

    texts.group_by do |txt|
      txt && txt[:bill_ident]
    end
  end

  # TODO: Should be private
  def self.parse_file (bill, text_version, input_path, output_path, options = {})
    file = File.open(input_path, 'r')
    file_timestamp = File.mtime(input_path)
    doc = REXML::Document.new file

    version = bill.bill_text_versions.find_or_create_by_version(text_version)
    OCLogger.log "Parsing bill text: #{input_path} -> #{output_path}"


    version.word_count = get_text_word_count(bill, text_version)

    # now parse the html
    doc_root = doc.root

    version.previous_version = doc_root.attributes['previous-status']
    version.difference_size_chars = doc_root.attributes['difference-size-chars']
    version.percent_change = doc_root.attributes['percent-change']
    version.total_changes = doc_root.attributes['total-changes']
    version.file_timestamp = file_timestamp
    version.save
    bill.save

    doc_root.name = 'div'

    tree_walk(doc_root, version)

    outdir = File.dirname(output_path)
    FileUtils.mkdir_p(outdir)
    File.open(output_path, 'w+') do |outfile|
      doc.write outfile
    end
  end
end


$node_order = 0

def tree_walk(element, version, in_inline = false, in_removed = false)
  removed = false

  unless element.has_elements?
    if element.name == 'p' and element.text.blank?
      element.parent.delete(element)
    end
  end

  element.elements.to_a.each do |e|
    case e.name
    when 'changed'
       e.name = 'span'
       e.attributes['class'] = 'bill_text_changed'
    when 'changed-from'
       e.name = 'span'
       e.attributes['class'] = 'bill_text_changed_from'
       e.attributes['style'] = 'display: none;'
    when 'changed-to'
       e.name = 'span'
       e.attributes['class'] = 'bill_text_changed_to'
    when 'inserted'
      e.attributes['class'] = "bill_text_inserted"

      e.name = in_inline ? 'span' : 'div'
    when 'removed'
      e.attributes['class'] = "bill_text_removed"
      e.attributes['style'] = "display: none;"
      removed = true

      e.name = in_inline ? 'span' : 'div'
    when 'p'
      #e.name = 'span' if in_inline
    when 'ul'
      e.name = 'span' if in_inline
    when 'h2','h3','h4'
      if in_inline
        e.name = 'span'
        e.attributes['style'] = "font-size: 14px; font-weight:bold;"
      end
    end

    unless e.attributes['nid'].nil? or e.name == 'h2' or e.name == 'h3' or e.name == 'h4' or in_removed
      e.attributes['class'] = 'bill_text_section'
      e.attributes['id'] = "bill_text_section_#{e.attributes['nid']}"
      e.attributes['onmouseover'] = "BillText.mouseOverSection('#{e.attributes['nid']}');"
      e.attributes['onmouseout'] = "BillText.mouseOutSection('#{e.attributes['nid']}');"

      menu = Element.new "span"
      menu.attributes['class'] = 'bill_text_section_menu'
      menu.attributes['id'] = "bill_text_section_menu_#{e.attributes['nid']}"
      menu.attributes['style'] = 'display:none;'

      comments_show = Element.new "a"
      comments_show.attributes['href'] = "#"
      comments_show.attributes['id'] = "show_comments_link_#{e.attributes['nid']}"
      comments_show.attributes['class'] = "small_button pushright"
      comments_show.attributes['onClick'] = "BillText.showComments(#{version.id}, '#{e.attributes['nid']}'); return false;"
      comments_show.text = ""

      comments_show_span = Element.new "span"
      comments_show_span.text = "Comments"

      comments_show.elements << comments_show_span

      comments_hide = Element.new "a"
      comments_hide.attributes['href'] = "#"
      comments_hide.attributes['id'] = "close_comments_link_#{e.attributes['nid']}"
      comments_hide.attributes['class'] = "small_button pushright"
      comments_hide.attributes['style'] = 'display:none;'
      comments_hide.attributes['onClick'] = "BillText.closeComments(#{version.id}, '#{e.attributes['nid']}'); return false;"
      comments_hide.text = ""

      comments_hide_span = Element.new "span"
      comments_hide_span.text = "Close Comments"

      comments_hide.elements << comments_hide_span

      permalink = Element.new "a"
      permalink.attributes['href'] = "?version=#{version.version}&nid=#{e.attributes['nid']}"
      permalink.attributes['id'] = "permalink_#{e.attributes['nid']}"
      permalink.attributes['class'] = "small_button"
      permalink.text = ""

      permalink_span = Element.new "span"
      permalink_span.text = "Permalink"

      permalink.elements << permalink_span

      comments = Element.new "div"
      comments.attributes['id'] = "bill_text_comments_#{e.attributes['nid']}"
      comments.attributes['class'] = 'bill_text_section_comments'
      comments.attributes['style'] = 'display:none;'
      comments.text = ""

      comments_clearer = Element.new "br"
      comments_clearer.attributes['class'] = 'clear'
      comments_clearer.text = ""

      comments.elements << comments_clearer

      img = Element.new "img"
      img.attributes['style'] = 'margin: 5px; text-align: center;'
      img.attributes['src'] = '/images/flat-loader.gif'

      comments.elements << img

      menu.elements << comments_show
      menu.elements << comments_hide
      menu.elements << permalink

      e.elements << menu
      e.elements << comments
    end

    tree_walk(e, version, (in_inline or (e.name  =~ /p|em|h2|h3|h4/)), (in_removed or removed))
  end
end

def get_text_word_count (bill, text_version)
  # get the word count from the text file
  govtrack_bill_type = bill.reverse_abbrev_lookup
  versioned_path = "#{Settings.govtrack_billtext_path}/#{bill.session}/#{govtrack_bill_type}/#{govtrack_bill_type}#{bill.number}#{text_version}.txt"
  plain_path = "#{Settings.govtrack_billtext_path}/#{bill.session}/#{govtrack_bill_type}/#{govtrack_bill_type}#{bill.number}.txt"
  path = File.exists?(versioned_path) ? versioned_path : plain_path
  File.open(path) do |text_file|
    raw_text = text_file.read

    #remove line numbers
    raw_text.gsub!(/^\s*\d+/, "")

    word_count = raw_text.scan(/(\w|-)+/).size

    raw_text = nil
    text_file.close

    return word_count
  end
end


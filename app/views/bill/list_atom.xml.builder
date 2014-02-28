xml.instruct!

xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do

  xml.title   "Open Congress : #{@feed_title}"
  xml.link    "rel" => "self", "href" => url_for(:controller => "bill", :action => "atom_list", :chamber => @chamber, :sort => @sort, :only_path => false)
  xml.link    "rel" => "alternate", "href" => url_for({:only_path => false, :controller => 'bill', :action => 'all'}.merge(@chamber == 'all' ? {} : {:types => @chamber}))
  xml.updated @bills.first.last_action.datetime.strftime("%Y-%m-%dT%H:%M:%SZ") if @bills.any?
  xml.author  { xml.name "opencongress.org" }
  xml.id      "tag:opencongress.org,2007:/bill/#{@chamber}/#{@sort}"

  @bills.each do |b|
    if @sort == 'lastaction'
      bill_with_last_action_atom_entry(xml, b)
    else
      bill_basic_atom_entry(xml, b)
    end
  end
end
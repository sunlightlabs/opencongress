
def rank_mocs(chamber, stat)
  #update sponsor rank
  people = Person.find(:all, :include => [:roles, :person_stats], :conditions => ['roles.enddate > ? AND role_type = ? ', Date.today, chamber], :order => 'person_stats.'+ stat + ' DESC')

  rank = 0
  prev = nil

  people.each do |moc|
    if prev != moc.person_stats.send(stat)
        rank += 1
        prev = moc.person_stats.send(stat)
    end
    moc.person_stats.send(stat + '_rank=', rank)
    moc.person_stats.save
    puts 'added rank %s on %s %s %s for %s %s' % [moc.person_stats.send(stat+'_rank'), chamber, moc.firstname, moc.lastname, moc.person_stats.send(stat), stat]
  end
end



#Update sponsor and cosponsor stats on legislator
people = Person.legislator
people.each do |person|

  stats = person.person_stats
  #sponsor
  stats.sponsored_bills = Bill.where("sponsor_id = ? AND session = ?", person.id, Settings.default_congress).count

#Save sponsored_bills_passed for when we have the actions...?
#  stats.sponsored_bills_passed = Bill.where("sponsor_id = ? AND session = ? AND 

  #cosponser
  stats.cosponsored_bills = Bill.count(:all, :include => [:bill_cosponsors], :conditions =>["bills.session = ? AND person_id = ?", Settings.default_congress, person.id])

  stats.save()

end

rank_mocs('sen', 'sponsored_bills')
rank_mocs('rep', 'sponsored_bills')

rank_mocs('sen', 'cosponsored_bills')
rank_mocs('rep', 'cosponsored_bills')

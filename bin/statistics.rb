#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../config/environment'
require 'congress'

def committee_hearings(startyear=2012,startmonth=1,startday=1,enddate=DateTime.now(),delta=7)

  deltadate = DateTime.new(startyear,startmonth,startday)
  weeks = 0
  total = 0
  most = 0
  least = nil

  # containers for statistics
  stats = {}
  bins = ['senate','house','Hearing','Meeting','Markup','Business Meeting','Field Hearing','joint']
  bins.each {|item| stats[item] = {'total' => 0, 'most' => 0, 'least' => nil, 'avg/week' => 0, 'tmp_count' => 0} }

  # get all the data from Congress API
  page = 1
  hearing_dates = []
  while true
    data = Congress.hearings('occurs_at__gte' => deltadate.to_s.gsub('+00:00','Z'),'page' => page)
    if data['results'].empty? then break
    else
      hearing_dates += data['results']
      page += 1
    end
  end

  # sort the data into the bins
  while deltadate < enddate
    count = 0
    stats.keys.each {|key| stats[key]['tmp_count'] = 0 }
    hearing_dates.each {|item|
      dt = item['occurs_at'].to_datetime
      if dt > deltadate and dt < (deltadate + delta)
        begin
          stats[item['chamber']]['tmp_count'] += 1
        rescue
          stats['joint']['tmp_count'] += 1
        end
        if item.has_key?('hearing_type') then stats[item['hearing_type']]['tmp_count'] += 1 end
        count += 1
      end
    }

    most = count if count > most
    least = count if (least == nil or count < least)
    total += count

    stats.keys.each {|key|
      stats[key]['most'] = stats[key]['tmp_count'] if stats[key]['tmp_count'] > stats[key]['most']
      stats[key]['least'] = stats[key]['tmp_count'] if (stats[key]['least'] == nil or stats[key]['tmp_count'] < stats[key]['least'])
      stats[key]['total'] += stats[key]['tmp_count']
      puts "Total #{key} between #{deltadate.strftime('%B %e %Y')} and #{(deltadate+delta).strftime('%B %e %Y')}: #{stats[key]['tmp_count']}"
    }

    deltadate+=delta
    weeks+=1
  end

  # calculate the averages and remove the tmp_count
  stats.keys.each {|key|
    stats[key]['avg/week'] = stats[key]['total'] / weeks
    stats[key].delete('tmp_count')
  }
  stats['all'] = {'total' => total, 'most' => most, 'least' => least, 'avg/week' => total/weeks, 'tmp_count' => 0}

  return stats
end


def committee_membership

  buckets = {
      'committees' => {'maj' => {}, 'sub' => {}},
      'people' => {'maj' => [], 'sub' => []}
  }

  CommitteePerson.all.each {|cp|
    begin
      committee = Committee.find(cp.committee_id)
      if committee.active and cp.person_id != nil
        if committee.subcommittee_name == nil
          buckets['committees']['maj'][cp.committee_id] = Set.new unless buckets['committees']['maj'].has_key?(cp.committee_id)
          buckets['committees']['maj'][cp.committee_id].add(cp.person_id)
          buckets['people']['maj'].append(cp.person_id)
        else
          buckets['committees']['sub'][cp.committee_id] = Set.new unless buckets['committees']['sub'].has_key?(cp.committee_id)
          buckets['committees']['sub'][cp.committee_id].add(cp.person_id)
          buckets['people']['sub'].append(cp.person_id)
        end
      end
    rescue
      puts "Committee with id #{cp.committee_id} doesn't exist"
    end
  }

  stats = {}
  buckets['committees'].each {|key,val|
    stats[key] = {'least' => nil, 'most' => 0, 'committee_id_most' => 0, 'committee_id_least' => 0}
    buckets['committees'][key].each{|k,v|
      if buckets['committees'][key][k].size > stats[key]['most']
        stats[key]['most'] = buckets['committees'][key][k].size
        stats[key]['committee_id_most'] = k
      end
      if stats[key]['least'] == nil or buckets['committees'][key][k].size < stats[key]['least']
        stats[key]['least'] = buckets['committees'][key][k].size
        stats[key]['committee_id_least'] = k
      end
    }
  }

  stats['maj']['avg'] = buckets['people']['maj'].size / buckets['committees']['maj'].size
  stats['sub']['avg'] = buckets['people']['sub'].size / buckets['committees']['sub'].size

  return stats
end

def bills_with_subjects
  return BillSubject.select(:bill_id).uniq.count
end

def committee_bill_association
  committee = {}
  Committee.all.each{|c| committee[c.id] = BillCommittee.where(committee_id:c.id).count if c.active }
  return committee
end
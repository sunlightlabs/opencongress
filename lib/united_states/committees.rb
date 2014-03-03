module UnitedStates
  module Committees

    extend self
    extend ImportGuard

    @@ActiveCommitteeIds = Set.new

    def active_committee_id_cache_guard ()
      if @@ActiveCommitteeIds.size == 0
        cmtes_file_path = File.join(Settings.data_path,
                                    'congress-legislators',
                                    'committees-current.yaml')
        cmtes = YAML.load_file(cmtes_file_path)
        cmtes.each do |cmte|
          @@ActiveCommitteeIds.add cmte['thomas_id']
          cmte.fetch('subcommittees', []).each do |subcmte|
            @@ActiveCommitteeIds.add "#{cmte['thomas_id']}#{subcmte['thomas_id']}"
          end
        end
      end
    end

    def active_committee_ids
      @@ActiveCommitteeIds
    end

    def import_committee (cmte_hash, parent_cmte = nil)
      # raise ImportExpiredError if import_expired?
      return if import_expired?
      active_committee_id_cache_guard

      # parent_cmte will be non-nil if importing a subcommittee
      if parent_cmte
        thomas_id = "#{parent_cmte.thomas_id}#{cmte_hash['thomas_id']}"
      else
        thomas_id = cmte_hash['thomas_id']
      end

      cmte_rec = Committee.find_or_initialize_by_thomas_id(thomas_id)
      cmte_rec.name = parent_cmte.nil? ? cmte_hash['name'] : parent_cmte.name
      cmte_rec.subcommittee_name = parent_cmte.nil? ? nil : cmte_hash['name']
      chamber = parent_cmte.nil? ? cmte_hash['type'] : parent_cmte.chamber
      chamber &&= chamber.downcase
      cmte_rec.chamber = chamber
      cmte_rec.active = @@ActiveCommitteeIds.include? thomas_id
      cmte_rec.parent = parent_cmte # nil for top-level committees
      cmte_rec.save! and OCLogger.log("Saved #{cmte_rec.subcommittee_name || cmte_rec.name}")

      subcmte_hashes = cmte_hash.fetch('subcommittees', [])
      subcmte_hashes.each do |subcmte_hash|
        import_committee(subcmte_hash, cmte_rec)
      end

      names = cmte_hash.fetch('names', [])
      names.each do |session, name|
        name_rec = cmte_rec.names.find_or_initialize_by_session(session)
        name_rec.name = name
        name_rec.save!
      end
    end

    def import_membership (cmte_thomas_id, mem_hash)
      # raise ImportExpiredError if import_expired?
      return if import_expired?
      cmte = Committee.find_by_thomas_id cmte_thomas_id
      legislator = Person.find_by_bioguideid(mem_hash['bioguide'])
      if cmte && legislator
        membership = CommitteePerson.find_by_committee_id_and_person_id_and_session(cmte.id, legislator.id, CONGRESS)
        if membership.nil?
          membership = CommitteePerson.new
          membership.person_id = legislator.id
          membership.committee_id = cmte.id
        end
        created = membership.new_record?
        if created || membership.role != mem_hash['title'] || membership.session != CONGRESS
          membership.role = mem_hash['title']
          membership.session = CONGRESS
          membership.save! and OCLogger.log("#{created ? "Created" : "Updated"} membership: #{legislator.full_name} sitting on #{cmte.subcommittee_name || cmte.name} in the #{CONGRESS.ordinalize}")
        end
      end
    end

    def decode_meeting_hash (mtg_hash)
      mtg_hash['+occurs_at'] = Time.zone.parse(mtg_hash['occurs_at'])
      if mtg_hash['subcommittee']
        mtg_hash['+committee_id'] = "#{mtg_hash['committee']}#{mtg_hash['subcommittee']}"
      else
        mtg_hash['+committee_id'] = "#{mtg_hash['committee']}"
      end
      mtg_hash
    end

    def import_meeting (mtg_hash)
      # raise ImportExpiredError if import_expired?
      return if import_expired?
      mtg_hash = decode_meeting_hash(mtg_hash)
      OCLogger.log "Considering meeting for committee #{mtg_hash['+committee_id']} @ #{mtg_hash['+occurs_at']}"
      cmte = Committee.find_by_thomas_id(mtg_hash['+committee_id'])
      if cmte
        meeting = cmte.meetings.find_by_meeting_at(mtg_hash['+occurs_at'])
        unless meeting
          meeting = cmte.meetings.new
          OCLogger.log "Creating new meeting for committee #{mtg_hash['+committee_id']} @ #{mtg_hash['+occurs_at']}"
        end
        meeting.meeting_at = mtg_hash['+occurs_at']
        meeting.subject = mtg_hash['topic']
        meeting.where = case mtg_hash['chamber']
                        when 'house'
                          'h'
                        when 'senate'
                          's'
                        else
                          nil
                        end
        meeting.save!
      else
        OCLogger.log "No such committee #{mtg_hash['+committee_id']} referenced by meeting @ #{mtg_hash['+occurs_at']}"
      end
    end

    def import_committee_report_mods_file (rpt_path)
      # raise ImportExpiredError if import_expired?
      return if import_expired?
      begin
        mods = Nokogiri::XML(File.open(rpt_path))
        # We need to remove the namespaces because the XML doesn't properly
        # declare certain elements (e.g. congMember).
        mods.remove_namespaces!
      rescue Exception => e
        OCLogger.log "Cannot parse file #{rpt_path}: #{e.to_s}"
        return
      end

      rpt_attrs = extract_from_report_doc(mods)

      rpt_ident = {
        :number => rpt_attrs[:number],
        :kind => rpt_attrs[:kind],
        :congress => rpt_attrs[:congress]
      }
      rpt = CommitteeReport.where(rpt_ident).first
      if rpt.nil?
        OCLogger.log "Creating new committee report record for #{rpt_ident}"
        rpt = CommitteeReport.new
        rpt.update_attributes(rpt_ident)
      end

      if rpt_attrs[:bill]
        rpt.bill = Bill.where(rpt_attrs[:bill]).first
      end

      if rpt_attrs[:committee_id]
        rpt.committee = Committee.find_by_thomas_id(rpt_attrs[:committee_id])
      elsif rpt_attrs[:committee_name]
        cmte_name = rpt_attrs[:committee_name].gsub(/^(HOUSE|SENATE|JOINT)/, '').strip.downcase
        if rpt_attrs[:chamber] == 'house'
          cmte_name = "House #{cmte_name}"
        elsif rpt_attrs[:chamber] == 'senate'
          cmte_name = "Senate #{cmte_name}"
        end

        cmte_name = cmte_name.titlecase
        cmte = Committee.where(:subcommittee_name => cmte_name).first
        if cmte
          rpt.committee = cmte
        else
          cmte = Committee.where(:name => cmte_name).first
          rpt.committee = cmte
        end
      end

      if rpt_attrs[:submitted_by]
        rpt.person = Person.find_by_bioguideid(rpt_attrs[:submitted_by])
      end

      rpt.chamber = rpt_attrs[:chamber]
      rpt.gpo_id = rpt_attrs[:ident]
      rpt.reported_at = rpt_attrs[:date_issued]
      rpt.title = rpt_attrs[:title]
      rpt.save!
    end

    ##
    # Accepts a Nokogiri::XML::Document and an XPath expression (as a
    # string). Searches the document for the expression, returning the
    # first matching element or raising an exception.
    def element_guard (doc, expr)
      matches = doc.xpath(expr)
      (matches.length > 0) or raise MissingRequiredElement.new(expr)
      matches.first
    end

    def extract_from_report_doc (mods)
      ident = element_guard mods, '/mods/recordInfo/recordIdentifier'
      title = element_guard mods, '/mods/titleInfo/title/text()'
      date_issued = element_guard mods, '/mods/originInfo/dateIssued'

      committee1 = mods.xpath('/mods/extension/congCommittee[@authorityId]').to_a
      committee2 = mods.xpath('/mods/relatedItem[@type="constituent"]/extension/congCommittee[@authorityId]').to_a
      committee = committee1.concat(committee2).first

      ident_match = /^CRPT-(\d+)(.*rpt)(\d+)$/.match(ident.text)
      ident_match or raise DataValidationError.new("Invalid value in recordInfo/recordIdentifier: #{ident}")
      cong_num, rpt_kind, rpt_number = ident_match.captures
      chamber = case rpt_kind
                 when 'erpt'
                 when 'srpt'
                   'senate'
                 when 'hrpt'
                   'house'
                 end

      committee &&= committee['authorityId'].gsub(/00$/, '').upcase
      if committee.nil?

        cmte_name_matches = [
          '//recommendation/text()',
          '/mods/titleInfo/title/text()',
          '/mods/abstract/text()',
          '/mods/relatedItem[@type="constituent"]/extension/congCommittee',
          '/mods/extension/searchTitle/text()'
        ].flat_map do |sel|
          mods.xpath(sel).map do |txt|
            /(?:(?:JOINT|HOUSE|SENATE) )?((?:SELECT )?COMMITTEE ON(?: THE)? .+?)(?:(?:,|(?:[\s\b](?:during|on|of|for|the|submitted|covering|UNITED STATES|$)))[\s\b])/i.match(txt)
          end
        end
        cmte_name_matches.select! {|m| not m.nil?}
        cmte_name_matches.map! {|m| m.captures}
        committee_name = cmte_name_matches.first
        committee_name &&= committee_name.first.strip
      end

      # Some reports (e.g. legislative activities reports) don't have primary submitters
      # or primary bills associated, so these are optional.
      submitted_by = mods.xpath('/mods/extension/congMember[@bioGuideId and @role="SUBMITTEDBY"]').first
      submitted_by &&= submitted_by['bioGuideId']

      primary_bill = mods.xpath('/mods/extension/bill[@congress and @number and @type and @context="PRIMARY"]').first
      if primary_bill
        primary_bill = {
          :number => primary_bill['number'],
          :session => primary_bill['congress'],
          :bill_type => primary_bill['type'].downcase
        }
      end

      {
        :bill => primary_bill,
        :ident => ident.text,
        :kind => rpt_kind,
        :number => rpt_number,
        :congress => cong_num,
        :chamber => chamber,
        :submitted_by => submitted_by,
        :committee_id => committee,
        :committee_name => committee_name,
        :title => title.text,
        :date_issued => Date.parse(date_issued.text)
      }
    end
  end
end

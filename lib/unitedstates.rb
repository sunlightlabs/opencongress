require 'o_c_logger'
require 'json'
require 'time'

##
# Provides methods to parse and decode files from the
# @unitedstates repositories.
module UnitedStates

  class Error < StandardError
  end

  class DataValidationError < Error
  end

  class MissingRequiredElement < DataValidationError
  end

  class Bills
    def self.Abbreviations
      {
        "hconres" => "H.Con.Res.",
        "hjres" => "H.J.Res.",
        "hr" => "H.R.",
        "hres" => "H.Res.",
        "s" => "S.",
        "sconres" => "S.Con.Res.",
        "sjres" => "S.J.Res.",
        "sres" => "S.Res."
      }
    end

    def self.parse_bill_file (path)
      decode_bill_hash(JSON.parse(File.read(path)))
    end

    ##
    # Decodes string representations of datetime and numeric
    # fields. Typed field names are prefixed with +.
    def self.decode_bill_hash (bill_hash)
      bill_hash['actions'].each do |action|
        action['+acted_at'] = Time.parse(action['acted_at'])
      end
      bill_hash['actions'].sort_by! { |action| action['+acted_at'] }
      bill_hash['+introduced_at'] = Time.parse(bill_hash['introduced_at'])
      bill_hash['+updated_at'] = Time.parse(bill_hash['updated_at'])
      bill_hash
    end

    ## 
    # Creates Bill and BillCommittee models to reflect
    # data in the given hash. It's assumed that the hash
    # has decoded fields.
    def self.import_bill (bill_hash)
      # TODO Guard against loading bills from other congresses
      bill_ident = { :session => bill_hash['congress'],
                     :bill_type => bill_hash['bill_type'],
                     :number => bill_hash['number'] }
      bill = Bill.where(bill_ident) .first
      if bill.nil?
        bill = Bill.new bill_ident
        OCLogger.log "Added bill #{bill_hash['bill_id']}"
      else
        OCLogger.log "Updating bill #{bill_hash['bill_id']}"
      end

      if bill.updated.nil? or bill_hash['+updated_at'] > bill.updated
        sponsor_id = bill_hash['sponsor'] and bill_hash['sponsor']['thomas_id']
        if not sponsor_id.nil?
          sponsor = Person.find_by_thomas_id bill_hash['sponsor']['thomas_id']
          if not sponsor.nil?
            bill.sponsor_id = sponsor.id
          else
            OCLogger.log "Bill data contains a sponsor id (#{sponsor_id}) that does not exist in our database."
          end
        end
        # TODO: What is the `pl` field for?
        # Where does rolls get set?
        # TODO: Fields I think we can drop because I can't find 
        # any code that uses them:
        #     last_vote_where #     last_vote_roll
        #     last_speech
        #
        bill.introduced = bill_hash['+introduced_at'].to_i
        if bill_hash['actions'].length > 0
          bill.lastaction = bill_hash['actions'].last['+acted_at'].to_i
        end
        topresident = bill_hash['actions'].select do |action|
          action['type'] == 'topresident'
        end .first
        if not topresident.nil?
          bill.topresident_date = topresident['+acted_at'].to_i
          bill.topresident_datetime = topresident['+acted_at']
        end

        bill.summary = bill_hash['summary'] and bill_hash['summary']['text']
        bill.updated = bill_hash['+updated_at']
        bill.save!

        # Import bill titles.
        # We want all bill titles, not just current ones.
        bill_hash['titles'].each do |title|
          title_ident = { :title => title['title'],
                          :as => title['as'],
                          :title_type => title['type'] }
          bill_title = bill.bill_titles.where(title_ident) .first
          if bill_title.nil?
            OCLogger.log "Adding new bill title for #{bill.bill_id}: '#{title['title']}'"
            bill_title = bill.bill_titles.create title_ident
          end
        end

        # Import list of committees for this bill
        bill_hash['committees'].each do |cmte|
          bill_cmte = bill.committees.find_by_thomas_id(cmte['committee_id'])
          if bill_cmte.nil?
            OCLogger.log "Associating #{bill.bill_id} with committee #{cmte['committee_id']}"
            committee = Committee.find_by_thomas_id cmte['committee_id']
            if not committee.nil?
              bill.committees << committee
            end
          end
        end

        import_amendments bill_hash
        import_bill_actions bill_hash
      else
        OCLogger.log "#{bill_hash['bill_id']} is already up-to-date."
      end
    end

    def self.import_bill_actions (bill_hash)
      bill_ident = { :session => bill_hash['congress'],
                     :bill_type => bill_hash['bill_type'],
                     :number => bill_hash['number'] }
      bill = Bill.where(bill_ident) .first
      if not bill.nil?
        intro = bill.actions.find_by_action_type 'introduced'
        if intro.nil?
          intro = bill.actions.new :action_type => 'introduced'
        end
        intro.date = bill_hash['+introduced_at'].to_i
        intro.datetime = bill_hash['+introduced_at']
        intro.save!

        bill_hash['actions'].each do |act|
          action_ident = { :action_type => act['type'],
                           :date => act['+acted_at'].to_i,
                           :datetime => act['+acted_at'],
                           :text => act['text'] }
          action = bill.actions.where(action_ident) .first
          if action.nil?
            action = bill.actions.new action_ident
          end
          action.save!
        end
      end
    end

    def self.import_amendments (bill_hash)
      bill_ident = { :session => bill_hash['congress'],
                     :bill_type => bill_hash['bill_type'],
                     :number => bill_hash['number'] }
      bill = Bill.where(bill_ident) .first
      if not bill.nil?
        bill_hash['amendments'].each do |amdt|
          bill.amendments.find_or_create_by_number(amdt['number'])
        end
      end
    end

    def self.link_related_bills (bill_hash)
      bill_hash['related_bills'].each do |related|
        r_type, r_number, r_session = Bill.ident(related['bill_id'])
        if not (r_type.nil? or r_number.nil? or r_session.nil?)
          bill_ident = { :session => bill_hash['congress'],
                         :bill_type => bill_hash['bill_type'],
                         :number => bill_hash['number'] }
          related_ident = { :session => r_session,
                            :bill_type => r_type,
                            :number => r_number }
          bill = Bill.where(bill_ident) .first
          related_bill = Bill.where(related_ident) .first
          if related_bill.nil?
            OCLogger.log "Cannot relate #{bill_hash['bill_id']} to #{related['bill_id']} because #{related['bill_id']} is not yet in the datebase."
          elsif not bill.nil?
            relation = BillRelation.find_by_bill_id_and_related_bill_id(bill.id, related_bill.id)
            if relation.nil?
              OCLogger.log "Relating bill #{bill_hash['bill_id']} to #{related['bill_id']}"
              bill.related_bills << related_bill
            end
          end
        end
      end
    end

    def self.parse_amendment_file (path)
      decode_amendment_hash(JSON.parse(File.read(path)))
    end

    def self.decode_amendment_hash (amdt_hash)
      amdt_hash['+status_at'] = Time.parse(amdt_hash['status_at'])
      amdt_hash['+updated_at'] = Time.parse(amdt_hash['updated_at'])
      amdt_hash['actions'].each do |action|
        action['+acted_at'] = Time.parse(action['acted_at'])
      end
      amdt_hash
    end

    def self.import_amendment (amdt_hash)
      bill_ident = {
        :session => amdt_hash['amends_bill']['congress'],
        :number => amdt_hash['amends_bill']['number'],
        :bill_type => amdt_hash['amends_bill']['bill_type']
      }
      bill = Bill.where(bill_ident).first
      if bill
        abbr_amdt_id = "#{amdt_hash['chamber']}#{amdt_hash['number']}"
        amdt_ident = {
          :number => abbr_amdt_id,
          :bill_id => bill.id
        }
        amdt = Amendment.where(amdt_ident).first
        if amdt
          OCLogger.log "Updating amendment #{amdt_hash['amendment_id']}"
        else
          OCLogger.log "Creating record for amendment #{amdt_hash['amendment_id']}"
          amdt = Amendment.new
          amdt.number = abbr_amdt_id
        end
        amdt.status = amdt_hash['status']
        amdt.status_date = amdt_hash['+status_at'].to_i
        amdt.status_datetime = amdt_hash['+status_at']
        amdt.offered_date = amdt_hash['+introduced_at'].to_i
        amdt.offered_datetime = amdt_hash['+introduced_at']
        amdt.bill_id = bill.id
        amdt.purpose = amdt_hash['purpose']
        amdt.updated = amdt_hash['+updated_at']
        amdt.save!
      else
        OCLogger.log "Amendment #{amdt_hash['amendment_id']} references unrecognized bill #{amdt_hash['amends_bill']['bill_id']}"
      end
    end
  end

  class Votes
    def self.parse_roll_call_file (path)
      decode_roll_call_hash(JSON.parse(File.read(path)))
    end

    ##
    # Decodes string representations of datetime and numeric
    # fields. Typed field names are prefixed with +.
    def self.decode_roll_call_hash (rc_hash)
      rc_hash['+date'] = Time.parse(rc_hash['date'])
      rc_hash['+updated_at'] = Time.parse(rc_hash['updated_at'])
      rc_hash
    end

    def self.import_roll_call (rc_hash)
      rc_ident = {
        :number => rc_hash['number'],
        :date => rc_hash['+date']
      }
      roll_call = RollCall.where(rc_ident).first
      if roll_call.nil?
        roll_call = RollCall.new(rc_ident)
      end

      if rc_hash['chamber'] == 'h'
        roll_call.where = 'house'
      elsif rc_hash['chamber'] == 's'
        roll_call.where = 'senate'
      else
        OCLogger.log "Unrecognized chamber: #{rc_hash['chamber']}"
      end
      roll_call.date = rc_hash['+date']
      roll_call.roll_type = rc_hash['type']
      roll_call.result = rc_hash['result']
      if rc_hash['votes']
        roll_call.ayes = (rc_hash['votes']['Yea'] or
                          rc_hash['votes']['Aye'] or
                          []).length
        roll_call.nays = (rc_hash['votes']['Nay'] or
                          rc_hash['votes']['No'] or
                          []).length
        roll_call.abstains = (rc_hash['votes']['Not Voting'] or []).length
        roll_call.presents = (rc_hash['votes']['Present'] or []).length
      end
      # No idea where these are set
      # roll_call.democratic_position
      # roll_call.republican_position
      roll_call.title = rc_hash['question'][0..254]
      roll_call.updated = rc_hash['+updated_at']
      roll_call.filename = rc_hash['source_url']
      roll_call.save!

      if rc_hash.include? 'bill'
        bill_ident = {
          :session => rc_hash['bill']['congress'],
          :number => rc_hash['bill']['number'],
          :bill_type => rc_hash['bill']['type']
        }
        bill = Bill.where(bill_ident).first
        if bill
          OCLogger.log "Linking roll call #{rc_hash['number']} to bill #{rc_hash['bill']['type']}#{rc_hash['bill']['number']}"
          bill.roll_calls << roll_call

          if rc_hash.include? 'amendment'
            # The data.json file calls a number the numeric potion of the vote "number" while
            # the database field is a string because it is prefixed by 's' or 'h'.
            amend_num_str = "#{rc_hash['amendment']['type']}#{rc_hash['amendment']['number']}"
            amendment = bill.amendments.where(:number => amend_num_str).first
            if amendment
              OCLogger.log "Linking roll call #{amend_num_str} on bill #{rc_hash['bill']['type']}#{rc_hash['bill']['number']} to amendment #{amend_num_str}"
              amendment.roll_calls << roll_call
            else
              OCLogger.log "Roll call #{roll_call.number} references unrecognized amendment #{amend_num_str}."
            end
          end
        else
          OCLogger.log "Roll call #{roll_call.number} references unrecognized bill #{rc_hash['bill']['type']}#{rc_hash['bill']['number']}"
        end

        import_roll_call_votes rc_hash
      end
    end

    def self.import_roll_call_votes (rc_hash)
      rc_ident = {
        :number => rc_hash['number'],
        :date => rc_hash['+date']
      }
      roll_call = RollCall.where(rc_ident).first
      if roll_call
        rc_hash['votes'].each do |vote_label, vote_hashes|
          vote_hashes.each do |vote_hash|
            if roll_call.where == 'house'
              voter = Person.find_by_bioguideid(vote_hash['id'])
            else
              voter = Person.find_by_lis_id(vote_hash['id'])
            end
            if voter
              vote = voter.roll_call_votes.find_by_roll_call_id(roll_call.id)
              if vote.nil?
                vote = voter.roll_call_votes.new
                vote.roll_call_id = roll_call.id
              end
              vote.vote = vote_label
              vote.save!
            else
              OCLogger.log "Roll call #{roll_call.where}#{roll_call.number} references unrecognized voter #{vote_hash['id']}"
            end
          end
        end
      end
    end
  end

  class Committees
    @@ActiveCommitteeIds = Set.new

    def self.active_committee_id_cache_guard ()
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

    def self.active_committee_ids
      @@ActiveCommitteeIds
    end

    def self.import_committee (cmte_hash, parent_cmte = nil)
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
      cmte_rec.save!

      #TODO: Also, memberships

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

    def self.import_membership (cmte_thomas_id, mem_hash)
      cmte = Committee.find_by_thomas_id cmte_thomas_id
      legislator = Person.find_by_bioguideid(mem_hash['bioguide'])
      if cmte and legislator
        membership = CommitteePerson.find_by_committee_id_and_person_id(cmte.id, legislator.id)
        if not membership
          membership = CommitteePerson.new
          membership.person_id = legislator.id
          membership.committee_id = cmte.id
        end
        membership.role = mem_hash['title']
        membership.session = nil
        membership.save!
      end
    end

    def self.decode_meeting_hash (mtg_hash)
      mtg_hash['+occurs_at'] = Time.parse(mtg_hash['occurs_at'])
      if mtg_hash['subcommittee']
        mtg_hash['+committee_id'] = "#{mtg_hash['committee']}#{mtg_hash['subcommittee']}"
      else
        mtg_hash['+committee_id'] = "#{mtg_hash['committee']}"
      end
      mtg_hash
    end

    def self.import_meeting (mtg_hash)
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

    def self.import_committee_report_mods_file (rpt_path)
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
    def self.element_guard (doc, expr)
      matches = doc.xpath(expr)
      (matches.length > 0) or raise MissingRequiredElement.new(expr)
      matches.first
    end

    def self.extract_from_report_doc (mods)
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

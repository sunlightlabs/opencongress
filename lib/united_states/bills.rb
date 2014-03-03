module UnitedStates
  module Bills

    extend self

    ABBREVIATIONS = HashWithIndifferentAccess.new({
      "hconres" => "H.Con.Res.",
      "hjres" => "H.J.Res.",
      "hr" => "H.R.",
      "hres" => "H.Res.",
      "s" => "S.",
      "sconres" => "S.Con.Res.",
      "sjres" => "S.J.Res.",
      "sres" => "S.Res."
    })

    def abbreviation_for(abbr)
      ABBREVIATIONS[abbr]
    end

    def abbreviation_from(abbr)
      ABBREVIATIONS.invert[abbr.to_s]
    end

    def file_path (congress, bill_type, number)
      File.join(Settings.unitedstates_data_path,
                congress.to_s,
                'bills',
                bill_type,
                "#{bill_type}#{number}",
                "data.json")
    end

    def parse_bill_file (path)
      decode_bill_hash(JSON.parse(File.read(path)))
    end

    ##
    # Decodes string representations of datetime and numeric
    # fields. Typed field names are prefixed with +.
    def decode_bill_hash (bill_hash)
      bill_hash['actions'].each_with_index do |action, idx|
        action['+acted_at'] = Time.zone.parse(action['acted_at'])
        action['+ordinal_position'] = idx
      end
      bill_hash['actions'].sort_by! { |action| action['+acted_at'] }
      bill_hash['+introduced_at'] = Time.zone.parse(bill_hash['introduced_at'])
      bill_hash['+updated_at'] = Time.zone.parse(bill_hash['updated_at'])
      bill_hash
    end

    ##
    # Gets a where-able set of params for the given result of decode_bill_hash
    def bill_ident (bill_hash)
      { :session => bill_hash['congress'],
        :bill_type => bill_hash['bill_type'],
        :number => bill_hash['number'] }
    end

    ##
    # Creates Bill and BillCommittee models to reflect
    # data in the given hash. It's assumed that the hash
    # has decoded fields.
    def import_bill (bill_hash, options = {})
      bill = Bill.where(bill_ident(bill_hash)).first
      if bill.nil?
        bill = Bill.new bill_ident(bill_hash)
        OCLogger.log "Added bill #{bill_hash['bill_id']}"
      else
        OCLogger.log "Updating bill #{bill_hash['bill_id']}"
      end

      if options[:force] || options[:dryrun] || bill.updated.nil? || (bill_hash['+updated_at'] > bill.updated)
        # Assign sponsor
        sponsor_id = bill_hash['sponsor'] && bill_hash['sponsor']['thomas_id']
        unless sponsor_id.nil?
          sponsor = Person.find_by_thomas_id bill_hash['sponsor']['thomas_id']
          if sponsor.nil?
            OCLogger.log "Bill data contains a sponsor id (#{sponsor_id}) that does not exist in our database."
          else
            bill.sponsor_id = sponsor.id
          end
        end

        bill_hash.fetch('cosponsors', []).each do |cosponsor_hash|
          cosponsor_id = cosponsor_hash['thomas_id']
          cosponsor = Person.find_by_thomas_id(cosponsor_id)
          if cosponsor.nil?
            OCLogger.log "Bill data contains a co-sponsor id (#{cosponsor_id}) that does not exist in our database."
          else
            if not bill.co_sponsors.exists?(cosponsor)
              bill.co_sponsors << cosponsor
            end
          end
        end

        # TODO: What is the `pl` field for?
        # Where does rolls get set?
        # TODO: Fields I think we can drop because I can't find
        # any code that uses them:
        #     last_vote_where #     last_vote_roll
        #     last_speech
        #

        # Bill actions
        bill.introduced = bill_hash['+introduced_at'].to_i
        if bill_hash['actions'].length > 0
          bill.lastaction = bill_hash['actions'].last['+acted_at'].to_i
        end
        topresident = bill_hash['actions'].select do |action|
          action['type'] == 'topresident'
        end .first
        unless topresident.nil?
          bill.topresident_date = topresident['+acted_at'].to_i
          bill.topresident_datetime = topresident['+acted_at']
        end

        # Summary
        bill.summary = bill_hash['summary'] && bill_hash['summary']['text']
        bill.updated = bill_hash['+updated_at']
        if bill_hash['subjects_top_term']
          subj = Subject.find_by_term(bill_hash['subjects_top_term'])
          if subj
            bill.top_subject = subj
          else
            bill.top_subject = nil
          end
        end
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
            unless committee.nil?
              bill.committees << committee
            end
          end
        end

        import_bill_actions bill_hash
        assign_subjects bill_hash
      else
        OCLogger.log "#{bill_hash['bill_id']} is already up-to-date."
      end
    end

    def warn_about_duplicate_actions (groups)
      groups.each do |id_hash, grp|
        if grp.size > 1
          OCLogger.log "Actions are not unique. There are #{grp.size} actions with identity #{id_hash}"
        end
      end
    end

    def bulk_destroy_actions (to_remove)
      if !to_remove.nil? && to_remove.length > 0
        bye_actions = Action.where(:id => to_remove.map(&:id))
        OCLogger.log "Removing #{bye_actions.length} spurious actions for #{to_remove.first.bill.ident}"
        bye_actions.destroy_all
      end
    end

    def import_bill_actions (bill_hash)
      # There are often multiple CR references associated with a single
      # bill action. This results in duplicate bill actions with different
      # 'references' membrs. Since we don't expose CR references we consider
      # these duplicates and discard all but the earliest one.
      bill = Bill.where(bill_ident(bill_hash)).first
      unless bill.nil?
        src_action_identity = proc { |act|
          { 'text' => act['text'],
            'datetime' => act['+acted_at'].in_time_zone,
            'where' => act['where'],
            'in_committee' => act['in_committee'],
            'in_subcommittee' => act['in_subcommittee']
          }
        }
        src_action_groups = bill_hash['actions'].group_by(&src_action_identity)
        warn_about_duplicate_actions src_action_groups

        existing_action_identity = proc { |act|
          { 'text' => act.text,
            'datetime' => act.datetime,
            'where' => act.where,
            'in_committee' => act['in_committee'],
            'in_subcommittee' => act['in_subcommittee']
          }
        }
        existing_action_groups = bill.actions.group_by(&existing_action_identity)

        # We want to remove actions from the database that no longer appear in
        # the source data. However since we synthetically create some of our
        # 'introduced' actions, we cannot remove those.
        to_remove = existing_action_groups.keys - src_action_groups.keys
        to_remove = to_remove.flat_map{ |act_identity| existing_action_groups[act_identity] }
        to_remove.reject!{ |act| act['action_type'] == 'introduced' }
        bulk_destroy_actions(to_remove)

        # Sometimes there are too many actions that map to the same identity hash. Let's
        # delete those too.
        src_action_groups.each do |act_identity, src_acts|
          existing_actions = existing_action_groups.fetch(act_identity, [])
          existing_actions.sort_by!{ |a| a['ordinal_position'] }
          surplus_count = existing_actions.length - src_acts.length
          if surplus_count > 0
            bulk_destroy_actions(existing_actions.pop(surplus_count))
          end
        end

        src_action_groups.each do |act_identity, src_acts|

          existing_actions = existing_action_groups.fetch(act_identity, [])
          existing_actions.sort_by!{ |a| a['ordinal_position'] }

          src_acts.sort_by{ |a| a['ordinal_position'] }.each_with_index do |act, src_idx|
            if src_idx < existing_actions.length
              action = existing_actions[src_idx]
            else
              action = bill.actions.new(act_identity)
            end
            updates = act.slice('text', 'where', 'in_committee', 'in_subcommittee', 'where', 'result', 'vote_type')
            updates['ordinal_position'] = act['+ordinal_position']
            updates['roll_call_number'] = act['roll']
            action.update_attributes!(updates)
          end
        end

        establish_introduced_action bill, bill_hash['+introduced_at']
      end
    end


    def establish_introduced_action (bill, introduced_at)
      # Some bills don't have an 'introduced' action in their actions list.
      # This creates a synthetic 'introduced' action for such bills if the
      # source data contains an introduced_at datetime field.
      if !introduced_at.nil?
        intro = bill.actions.find_by_action_type('introduced')
        intro ||= bill.actions.new(:action_type => 'introduced')
        intro.date = introduced_at.to_i
        intro.datetime = introduced_at
        intro.ordinal_position = -1
        intro.save! if intro.changed?
      end
    end

    def assign_subjects (bill_hash)
      bill = Bill.where(bill_ident(bill_hash)).first
      existing_subjects = bill.subjects.collect(&:term).sort
      to_remove = existing_subjects - bill_hash['subjects'].sort
      to_remove.each do |term|
        subj = Subject.find_by_term term
        unless subj.nil?
          OCLogger.log "De-associating invalid subject '#{term}' from #{bill.bill_id} (This is NOT normal)."
          BillSubject.where(:bill_id => bill.id, :subject_id => subj.id).each(&:destroy)
        end
      end
      bill_hash['subjects'].each do |term|
        subj = Subject.find_by_term_icase term
        if subj.nil?
          OCLogger.log "Creating new Subject '#{term}'"
          subj = Subject.create(:term => term)
          # TODO: Capture failures and send email
        end
        bs = BillSubject.new(:bill_id => bill.id, :subject_id => subj.id)
        if bs.save
          OCLogger.log "Associating #{bill.bill_id} with subject '#{term}'"
        # else
        #   OCLogger.log "Didn't associate #{bill.bill_id} with subject '#{term}': #{bs.errors.full_messages.to_sentence}"
        end
      end
    end

    def link_related_bills (bill_hash)
      bill_hash['related_bills'].each do |related|
        r_type, r_number, r_session = Bill.ident(related['bill_id'])
        unless (r_type.nil? or r_number.nil? or r_session.nil?)
          related_ident = { :session => r_session,
                            :bill_type => r_type,
                            :number => r_number }
          bill = Bill.where(bill_ident(bill_hash)).first
          related_bill = Bill.where(related_ident).first
          if related_bill.nil?
            OCLogger.log "Cannot relate #{bill_hash['bill_id']} to #{related['bill_id']} because #{related['bill_id']} is not yet in the datebase."
          elsif bill.present?
            relation = BillRelation.find_by_bill_id_and_related_bill_id(bill.id, related_bill.id)
            if relation.nil?
              OCLogger.log "Relating bill #{bill_hash['bill_id']} to #{related['bill_id']}"
              bill.related_bills << related_bill
            end
          end
        end
      end
    end

    def parse_amendment_ident_string (amdt_id)
      pattern = /([sh]amdt)(\d+)-(\d+)/
      match = pattern.match(amdt_id)
      if match
        match.captures
      else
        [nil, nil, nil]
      end
    end

    def amendment_file_path (congress, amdt_type, number)
      File.join(Settings.unitedstates_data_path,
                congress.to_s,
                'amendments',
                amdt_type,
                "#{amdt_type}#{number}",
                "data.json")
    end

    def parse_amendment_file (path)
      decode_amendment_hash(JSON.parse(File.read(path)))
    end

    def decode_amendment_hash (amdt_hash)
      amdt_hash['+status_at'] = Time.zone.parse(amdt_hash['status_at'])
      amdt_hash['+updated_at'] = Time.zone.parse(amdt_hash['updated_at'])
      amdt_hash['+introduced_at'] = Time.zone.parse(amdt_hash['introduced_at'])
      amdt_hash['actions'].each do |action|
        action['+acted_at'] = Time.zone.parse(action['acted_at'])
        action['+where'] = case action['where']
                           when 'h' then 'house'
                           when 's' then 'senate'
                           else action['where']
                           end
      end
      amdt_hash
    end

    def import_amendment (amdt_hash)
      bill = Bill.where(bill_ident(amdt_hash['amends_bill'])).first
      if bill
        abbr_amdt_id = "#{amdt_hash['chamber']}#{amdt_hash['number']}"
        amdt = bill.amendments.find_by_number(abbr_amdt_id)
        if amdt.nil?
          OCLogger.log "Creating record for amendment #{amdt_hash['amendment_id']}"
          amdt = Amendment.new
          amdt.number = abbr_amdt_id
          amdt.bill_id = bill.id
        end
        amdt.status = amdt_hash['status']
        amdt.status_date = amdt_hash['+status_at'].to_i
        amdt.status_datetime = amdt_hash['+status_at']
        amdt.offered_date = amdt_hash['+introduced_at'].to_i
        amdt.offered_datetime = amdt_hash['+introduced_at']
        amdt.purpose = amdt_hash['purpose']
        amdt.updated = amdt_hash['+updated_at']
        amdt.save! if amdt.changed?

        OCLogger.log "Linking amendment to roll calls"
        link_amendment_to_roll_calls amdt, amdt_hash
      else
        OCLogger.log "Amendment #{amdt_hash['amendment_id']} references unrecognized bill #{amdt_hash['amends_bill']['bill_id']}"
      end
    end

    def link_amendment_to_roll_calls (amdt, amdt_hash)
      (amdt_hash['actions'] or []).each do |action_hash|
        if action_hash['roll'] && action_hash['where']
          # We don't need to map this to the legislative year because the
          # RollCall.in_year scope is extracting the year from the timestamp
          # rather than using the congressional session.
          year = action_hash['+acted_at'].year
          roll_call = RollCall.in_year(year).where(:number => action_hash['roll'],
                                                   :where => action_hash['+where']).first
          if roll_call
            if roll_call.amendment.nil?
              amdt.roll_calls << roll_call
              OCLogger.log "Linking amendment #{amdt.id} to roll call #{roll_call.id}"
            end
          else
            OCLogger.log "Amendment #{amdt.id} references unrecognized roll call in action #{action_hash.to_s}"
          end
        end
      end
    end
  end
end

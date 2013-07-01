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
      bill_hash['actions'].each do |action|
        action['+acted_at'] = Time.parse(action['acted_at'])
      end
      bill_hash['actions'].sort_by! { |action| action['+acted_at'] }
      bill_hash['+introduced_at'] = Time.parse(bill_hash['introduced_at'])
      bill_hash['+updated_at'] = Time.parse(bill_hash['updated_at'])
      bill_hash
    end

    ##
    # Gets a where-able set of params for the given result of decode_bill_hash
    # TODO Guard against loading bills from other congresses
    def bill_ident (bill_hash)
      { :session => bill_hash['congress'],
        :bill_type => bill_hash['bill_type'],
        :number => bill_hash['number'] }
    end

    ##
    # Creates Bill and BillCommittee models to reflect
    # data in the given hash. It's assumed that the hash
    # has decoded fields.
    def import_bill (bill_hash)
      bill = Bill.where(bill_ident(bill_hash)).first
      if bill.nil?
        bill = Bill.new bill_ident(bill_hash)
        OCLogger.log "Added bill #{bill_hash['bill_id']}"
      else
        OCLogger.log "Updating bill #{bill_hash['bill_id']}"
      end

      if bill.updated.nil? or bill_hash['+updated_at'] > bill.updated
        # Assign sponsor
        sponsor_id = bill_hash['sponsor'] and bill_hash['sponsor']['thomas_id']
        unless sponsor_id.nil?
          sponsor = Person.find_by_thomas_id bill_hash['sponsor']['thomas_id']
          if sponsor.nil?
            OCLogger.log "Bill data contains a sponsor id (#{sponsor_id}) that does not exist in our database."
          else
            bill.sponsor_id = sponsor.id
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
            unless committee.nil?
              bill.committees << committee
            end
          end
        end

        import_amendments bill_hash
        import_bill_actions bill_hash
        assign_subjects bill_hash
      else
        OCLogger.log "#{bill_hash['bill_id']} is already up-to-date."
      end
    end

    def import_bill_actions (bill_hash)
      bill = Bill.where(bill_ident(bill_hash)).first
      unless bill.nil?
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

    def import_amendments (bill_hash)
      bill = Bill.where(bill_ident(bill_hash)).first
      unless bill.nil?
        bill_hash['amendments'].each do |amdt|
          bill.amendments.find_or_create_by_number(amdt['number'])
        end
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
        subj = Subject.find_by_term term
        if subj.nil?
          OCLogger.log "Creating new Subject '#{term}'"
          subj = Subject.create(:term => term)
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

    def parse_amendment_file (path)
      decode_amendment_hash(JSON.parse(File.read(path)))
    end

    def decode_amendment_hash (amdt_hash)
      amdt_hash['+status_at'] = Time.parse(amdt_hash['status_at'])
      amdt_hash['+updated_at'] = Time.parse(amdt_hash['updated_at'])
      amdt_hash['actions'].each do |action|
        action['+acted_at'] = Time.parse(action['acted_at'])
      end
      amdt_hash
    end

    def import_amendment (amdt_hash)
      bill = Bill.where(bill_ident(amdt_hash['amends_bill'])).first
      if bill
        abbr_amdt_id = "#{amdt_hash['chamber']}#{amdt_hash['number']}"
        amdt_ident = {
          :number => abbr_amdt_id,
          :bill_id => bill.id
        }
        amdt = Amendment.where(amdt_ident).first
        if amdt.nil?
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
end

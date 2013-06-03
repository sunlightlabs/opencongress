require 'o_c_logger'
require 'json'
require 'time'

##
# Provides methods to parse and decode files from the
# @unitedstates repositories.
module UnitedStates

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
        bill.lastaction = bill_hash['actions'].last['+acted_at'].to_i
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
        cmtes_file_path = File.join(Settings.unitedstates_legislators_clone_path, 'committees-current.yaml')
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
  end
end

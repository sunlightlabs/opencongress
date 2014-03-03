module UnitedStates
  module Votes
    extend self

    ##
    # s1-113.2013 => ['s', '1', '113', '2013']
    def parse_ident_string (s)
      pattern = /([sh])(\d+)-(\d+)[.](\d+)/
      match = pattern.match(s)
      if match
        return match.captures
      else
        return [nil, nil, nil, nil]
      end
    end

    def roll_call_file_path (congress, year, chamber_prefix, number)
      File.join(Settings.unitedstates_data_path,
                congress.to_s,
                'votes',
                year.to_s,
                "#{chamber_prefix}#{number}",
                "data.json")
    end

    def parse_roll_call_file (path)
      decode_roll_call_hash(JSON.parse(File.read(path)))
    end

    ##
    # Decodes string representations of datetime and numeric
    # fields. Typed field names are prefixed with +.
    def decode_roll_call_hash (rc_hash)
      rc_hash['+date'] = Time.zone.parse(rc_hash['date'])
      rc_hash['+updated_at'] = Time.zone.parse(rc_hash['updated_at'])
      if rc_hash['amendment'] && rc_hash['amendment']['type'] == 'h-bill' then
        rc_hash['amendment']['type'] = 'h'
      end
      rc_hash
    end

    def import_roll_call (rc_hash)
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
      roll_call.required = rc_hash['requires']
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
      roll_call.question = rc_hash['question'][0..254]
      roll_call.title = nil if roll_call.title == roll_call.question
      roll_call.updated = rc_hash['+updated_at']
      roll_call.filename = rc_hash['source_url']
      roll_call.save! if roll_call.changed?

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

          # Rather than use the roll call's amendment info (which is problematic, see
          # https://github.com/unitedstates/congress/issues/68 for details), we use the
          # amendment's action info to link to roll calls.
        else
          OCLogger.log "Roll call #{roll_call.number} references unrecognized bill #{rc_hash['bill']['type']}#{rc_hash['bill']['number']}"
        end
      end
      import_roll_call_votes rc_hash
    end

    def import_roll_call_votes (rc_hash)
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
              vote.vote = collapsed_vote_label(vote_label)
              vote.save! if vote.changed?
            else
              OCLogger.log "Roll call #{roll_call.where}#{roll_call.number} references unrecognized voter #{vote_hash['id']}"
            end
          end
        end
      end
    end

    def collapsed_vote_label (label)
      case label.downcase
        when 'aye', 'yea' then '+'
        when 'nay', 'no' then '-'
        when 'present', 'p' then 'P'
        when 'not voting' then '0'
        else label
      end
    end
  end
end

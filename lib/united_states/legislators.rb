module UnitedStates
  module Legislators
    extend self

    TERM_TYPE_TO_TITLE_MAPPING = {
      'sen' => 'Sen.',
      'rep' => 'Rep.'
    }

    GOVTRACK_ID_TO_TITLE_MAPPING = {
      400629 => 'Pres.',
      400295 => 'Del.'
    }

    ##
    # Decodes string representations of datetime and numeric
    # fields. Typed field names are prefixed with +.
    def decode_legislator_hash (leg_hash)
      latest_term = nil
      leg_hash['terms'].each do |term|
        term['+start'] = Date.parse(term['start'])
        term['+end'] = Date.parse(term['end'])

        if latest_term.nil? or term['+start'] > latest_term['+start']
          latest_term = term
        end
      end

      leg_hash['+latest_term'] = latest_term
      if Date.today.between?(latest_term['+start'], latest_term['+end'])
        leg_hash['+current_term'] = latest_term
      else
        leg_hash['+current_term'] = nil
      end

      if leg_hash['bio'] && leg_hash['bio']['birthday']
        leg_hash['bio']['+birthday'] = Date.parse(leg_hash['bio']['birthday'])
      end

      leg_hash
    end

    ##
    # Creates Person and Role models to reflect
    # data in the given hash. It's assumed that the hash
    # has decoded fields.
    def import_legislator (leg_hash)
      if leg_hash['id']['govtrack'].nil?
        OCLogger.log "Cannot import legislator without a govtrack ID: #{leg_hash.to_s}"
        return
      end

      if leg_hash['+latest_term'].nil?
        OCLogger "Cannot import legislator without term records: #{leg_hash['id']['govtrack']}"
        return
      end

      begin
        leg_person = Person.find(leg_hash['id']['govtrack'])
      rescue ActiveRecord::RecordNotFound
        leg_person = Person.new
        leg_person.id = leg_hash['id']['govtrack']
      end

      leg_person.govtrack_id = leg_hash['id']['govtrack']
      leg_person.thomas_id = leg_hash['id']['thomas']
      leg_person.fec_id = leg_hash['id']['fec']
      leg_person.lis_id = leg_hash['id']['lis']
      leg_person.cspan_id = leg_hash['id']['cspan']
      leg_person.bioguideid = leg_hash['id']['bioguide']
      leg_person.osid = leg_hash['id']['opensecrets']
      # leg_person.youtube_id came from govtrack's people.xml
      # but the unitedstates repo stores it in legislators-social-media.yml
      leg_person.lastname = leg_hash['name']['last']
      leg_person.firstname = leg_hash['name']['first']
      leg_person.nickname = leg_hash['name']['nickname']
      if leg_hash['name']['official_full']
        leg_person.name = leg_hash['name']['official_full']
      else
        leg_person.name = "#{leg_person.firstname} #{leg_person.lastname}".strip
      end

      title_override = GOVTRACK_ID_TO_TITLE_MAPPING[leg_hash['id']['govtrack']]
      if title_override
        leg_person.title = title_override
      else
        leg_person.title = TERM_TYPE_TO_TITLE_MAPPING[leg_hash['+latest_term']['type']]
      end

      if leg_hash['bio']
        leg_person.gender = leg_hash['bio']['gender']
        leg_person.religion = leg_hash['bio']['religion']
        if leg_hash['bio']['+birthday']
          leg_person.birthday = leg_hash['bio']['+birthday']
        end
      end

      leg_person.state = leg_hash['+latest_term']['state']
      leg_person.district = leg_hash['+latest_term']['district']
      leg_person.party = leg_hash['+latest_term']['party']
      if leg_hash['+current_term'].nil?
        leg_person.url = nil
        leg_person.fax = nil
        leg_person.phone = nil
        leg_person.contact_webform = nil
        leg_person.congress_office = nil
      else
        leg_person.url = leg_hash['+current_term']['url']
        leg_person.fax = leg_hash['+current_term']['fax']
        leg_person.phone = leg_hash['+current_term']['phone']
        leg_person.contact_webform = leg_hash['+current_term']['contact_form']
        leg_person.congress_office = leg_hash['+current_term']['address']

        state = State.find_or_create_by_abbreviation(leg_hash['+current_term']['state'])
        district = state.districts.find_or_create_by_district_number(leg_hash['+current_term']['district'])
      end

      leg_person.save! if leg_person.changed?

      leg_hash['terms'].each do |term_hash|
        import_role leg_person, term_hash
      end
    end

    # We call roles what the source data calls terms
    def import_role (person, term_hash)
      roles = person.roles.where("startdate = ? OR enddate = ?", term_hash['+start'], term_hash['+end'])
      if roles.count == 1
        role = roles.first
      else
        if roles.count > 1
          roles.destroy_all
        end
        role = person.roles.new(:startdate => term_hash['+start'],
                                :enddate => term_hash['+end'])
      end

      role.role_type = term_hash['type']
      role.party = term_hash['party']
      role.district = term_hash['district']
      role.state = term_hash['state']
      role.address = term_hash['address']
      role.url = term_hash['url']
      role.phone = term_hash['phone']

      role.save! if role.changed?
    end

  end
end


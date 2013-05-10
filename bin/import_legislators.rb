#!/usr/bin/env ruby

require 'rails'
require 'yaml'
require 'date'

require 'o_c_logger'

def usage
    program = File.basename($0)
    $stderr.puts <<-USAGE
    Unrecognized mode: #{ARGV[0]}
    Usage:
        #{program} current
        #{program} historical
USAGE
    exit
end

usage unless ARGV.length == 1
usage unless ['current', 'historical'].include? ARGV[0]


mode = ARGV[0]
legislators_file_path = File.join(Settings.unitedstates_legislators_clone_path, "legislators-#{mode}.yaml")
if not File.exists? legislators_file_path
    OCLogger.log "No such file: #{legislators_file_path}"
    exit
end

OCLogger.log "Parsing All Legislators from #{legislators_file_path}"
govtrack_id_to_title_mapping = {
    400629 => 'Pres.',
    400295 => 'Del.'
}

term_type_to_title_mapping = {
    'sen' => 'Sen.',
    'rep' => 'Rep.'
}

legislators = YAML.load_file(legislators_file_path)
legislators.each do |leg|
    latest_term = leg['terms'].sort_by { |t| Date.parse(t['start']) } .last
    current_term = leg['terms'].select do |t|
        start_date = Date.parse(t['start'])
        end_date = Date.parse(t['end'])
        Date.today.between? start_date, end_date
    end .first
    title = govtrack_id_to_title_mapping[leg['id']['govtrack']]
    title = term_type_to_title_mapping[current_term['type']] unless current_term.nil?

    begin
        leg_person = Person.find leg['id']['govtrack']
        OCLogger.log "Updating Legislator: #{leg['id']['govtrack']}"
    rescue ActiveRecord::RecordNotFound
        leg_person = Person.new
        OCLogger.log "Adding Legislator: #{leg['id']['govtrack']}"
    end

    leg_person.bioguideid = leg['id']['bioguide']
    leg_person.osid = leg['id']['opensecrets']
    # leg_person.youtube_id came from govtrack's people.xml
    # but the unitedstates repo stores it in legislators-social-media.yml
    leg_person.lastname = leg['name']['last']
    leg_person.firstname = leg['name']['first']
    leg_person.nickname = leg['name']['nickname']
    if leg['name']['official_full']
        leg_person.name = leg['name']['official_full']
    else
        leg_person.name = "#{leg_person.firstname} #{leg_person.lastname}".strip
    end
    leg_person.title = title
    if leg['bio']
        leg_person.gender = leg['bio']['gender']
        leg_person.religion = leg['bio']['religion']
        if not leg['bio']['birthday'].nil?
            leg_person.birthday = Date.parse(leg['bio']['birthday'])
        end
    end

    if latest_term.nil?
        puts "No term records for #{leg['id']['govtrack']}"
    else
        leg_person.state = latest_term['state']
        leg_person.district = latest_term['district']
        if current_term.nil?
            leg_person.url = nil
            leg_person.party = nil
        else
            leg_person.url = current_term['url']
            leg_person.party = current_term['party']
        end
    end

    # TODO from where should the :email field be sourced?
    # TODO unaccented_name appears unused. Let's get rid of it.
    leg_person.save!


    leg['terms'].each do |term|
        start_date = Date.parse(term['start'])
        end_date = Date.parse(term['end'])

        role = leg_person.roles.where(:startdate => start_date,
                                      :enddate => end_date) .last
        if role.nil?
            OCLogger.log "Updating #{term['type']} Role from #{start_date} to #{end_date}"
            role = leg_person.roles.new(:startdate => start_date,
                                        :enddate => end_date)
        else
            OCLogger.log "Added #{term['type']} Role from #{start_date} to #{end_date}"
        end

        role.role_type = term['type']
        role.party = term['party']
        role.district = term['district']
        role.state = term['state']
        role.address = term['address']
        role.url = term['url']
        role.phone = term['phone']
        # TODO The previous script set :email too, but people.xml didn't contains email
        # addresses, so I think it was unused.
        role.save!
    end
end


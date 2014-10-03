class MoveFecIdsToPersonIdentifiers < ActiveRecord::Migration
  def self.up
    non_arrays = []
    Person.where("fec_id IS NOT NULL").each do |person|
      fec_ids = YAML.load(person.fec_id)
      if fec_ids.class != Array
        puts "not an array"
        non_arrays << "#{person.firstname} #{person.lastname}"
      else
        puts "\n--------"
        puts "Creating PersonIdentifier(s) for #{person.firstname} #{person.lastname}"
        fec_ids.each do |id|
          pi = person.person_identifiers.new(
            namespace: "fec",
            value: id
          )
          if pi.save
            puts "saved id #{id} to #{person.firstname} #{person.lastname}"
          else
            puts "could not save id #{id} to #{person.firstname} #{person.lastname}"
          end
        end
      end
    end
    if non_arrays != []
      puts "Couldn't parse the fec id yaml of the following:"
      puts non_arrays
    end
    puts "People with FEC ids: #{Person.where("fec_id IS NOT NULL").count}"
    puts "Bioguide ids in PersonIdentifiers column: #{PersonIdentifier.select(:bioguideid).map(&:bioguideid).uniq.count}"
  end

  def self.down
    puts "This migration isn't smart enough for a down method. If you run something like PersonIdentifier.where(namespace: 'fec').destroy_all, you might take out FEC ids that were added after this migration. Tread lightly."
  end
end

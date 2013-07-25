class MapGroupsFromPvsCategoriesToCrsSubjects < ActiveRecord::Migration
  def self.up
    add_column :groups, :subject_id, :integer
   
    used_crs_names = [] 
    CSV.foreach('db/PVS-CRS.csv') do |row|
      pvs_name = row.first
      crs_name = row.second
      next if pvs_name == 'PVS' or crs_name == 'CRS' or crs_name.nil?

      pvs_category = PvsCategory.find_by_name(pvs_name)
      puts "Missing PVS category #{pvs_name}" if pvs_category.nil?
      crs_subject = Subject.find_by_term_icase(crs_name)
      puts "Missing CRS subject #{crs_name}" if crs_subject.nil?

      if crs_subject
        puts "#{pvs_name} => #{crs_name}"
        Group.in_category(pvs_category).each do |grp|
          grp.subject_id = crs_subject.id
          grp.save!

          if grp.name == "The #{pvs_name} Group" and Group.find_by_name(crs_name).nil? and not used_crs_names.include?(crs_name)
            grp.name = "The #{crs_name} Group"
            grp.save!
            used_crs_names.push(crs_name)
          end
        end
      end
    end
  end

  def self.down
    remove_column :groups, :subject_id
  end
end

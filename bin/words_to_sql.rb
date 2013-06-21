require 'o_c_logger'

if not File.exist?('words.txt')
  OCLogger.log "Cannot find words.txt. I think you need to run find_related_words.rb"
  exit
end

SubjectRelation.transaction do
  CSV(File.open('words.txt', 'r')).each_with_index do |record, idx|
    next if idx == 0 # Throw away the header

    a = record[0].to_i
    b = record[1].to_i
    cnt = record[2].to_i

    next if cnt <= 100 # Who cares about subjects that appear togther so rarely?

    rel_ident = { :subject_id => a.to_i,
                  :related_subject_id => b.to_i }
    rel = SubjectRelation.where(rel_ident).first
    if rel.nil?
      rel = SubjectRelation.new(rel_ident)
    end
    rel.relation_count = cnt
    rel.save! if rel.changed?

    OCLogger.log "Processed #{idx}" if idx % 10000 == 0
  end
end


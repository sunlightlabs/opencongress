class MakeSubjectUnique < ActiveRecord::Migration
  def self.up
    dups = Subject.group('lower(term)').count.select{ |term, cnt| cnt > 1 }
    dups.each do |term, cnt|
      subs = Subject.where(['lower(term) = ?', term]).order(:id)
      subs.shift
      subs.each do |sub|
        sub.destroy
      end
    end
  end

  def self.down
  end
end

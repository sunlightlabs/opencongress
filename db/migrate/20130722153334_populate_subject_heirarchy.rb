class PopulateSubjectHeirarchy < ActiveRecord::Migration
  def self.up
    # Placeholder subject that will never appear in a view.
    # Used for category/subject/term differentiation
    # parent_id value     means
    #             nil     is term
    #               n     us subject, n = id of parent
    #          top.id     is category
    top = Subject.find_or_initialize_by_term("\u22a4") # unicode "top"
    top.save!

    category = nil
    CSV.foreach('db/crssubjects.csv') do |row|
      subject = Subject.find_by_term_icase(row.first)
      if subject.nil?
        subject = Subject.new
        subject.term = row.first
      end
      if row.second == "1"
        category = subject
        subject.parent = top
      elsif category.nil? == false
        subject.parent = category
      end
      subject.save!
    end
  end

  def self.down
    Subject.update_all('parent_id = NULL')
    top = Subject.find_by_term("\u22a4")
    top.destroy if top
  end
end

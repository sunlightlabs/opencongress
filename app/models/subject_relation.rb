# == Schema Information
#
# Table name: subject_relations
#
#  id                 :integer          not null, primary key
#  subject_id         :integer
#  related_subject_id :integer
#  relation_count     :integer
#

class SubjectRelation < OpenCongressModel

  #========== RELATIONS

  #----- BELONGS_TO

  belongs_to :subject
  belongs_to :related_subject, :class_name => 'Subject', :foreign_key => :related_subject_id

  #========== METHODS

  #----- CLASS

  # This is a little tricky, because it represents a relationship that
  # ought to be symmetric. Retrieves all the related subjects for input subject.
  #
  # @param subject [Subject] subject model
  # @param number [Integer] result limit
  # @return [Array<Subject>]
  def self.related(subject, number)
    srs = SubjectRelation.includes(:subject, :related_subject).where('subject_id = ? OR related_subject_id = ?', subject.id, subject.id).order('relation_count DESC')
    srs = srs.limit(number) unless number.nil?
    add_up_related_subjects(subject, srs)
  end

  # Returns all the related subjects with no limit
  #
  # @param subject [Subject] subject model
  # @return [Array<Subject>]
  def self.all_related(subject)
    related(subject, nil)
  end

  # Gets all the related subject
  #
  # @return [Array<Subject>]
  def self.add_up_related_subjects(subject, srs)
    subjects = []
    srs.each {|sr| subjects.push(sr.subject == subject ? sr.related_subject : sr.subject) }
    subjects
  end

end
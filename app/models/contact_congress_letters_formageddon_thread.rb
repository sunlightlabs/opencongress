# == Schema Information
#
# Table name: contact_congress_letters_formageddon_threads
#
#  contact_congress_letter_id :integer
#  formageddon_thread_id      :integer
#

class ContactCongressLettersFormageddonThread < ActiveRecord::Base  
  belongs_to :formageddon_thread, :class_name => 'Formageddon::FormageddonThread'
  belongs_to :contact_congress_letter
end

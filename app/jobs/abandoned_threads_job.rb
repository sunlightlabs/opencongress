require 'authable'
require 'o_c_logger'

##
# AbandonedThreadsJob
#
# Cleans up, associates and sends (reclaims) Formageddon threads that got dropped through the sign-in process
#
# This is necessary because not everybody follows through the login process, and threads have to be saved
# anonymously before they can be associated after login.
#
# Usage: AbandonedThreadsJob.perform(:remove => [:orphaned, :inactive], # delete inactive and 'orphaned' threads
#                                    :reclaim => true,                  # send any that can be associated to valid users
#                                    :since => '2013-10-28',            # limit the list to threads created after this date
#                                    :older_than => 10.days)            # limit the list to threads that are older than this age (leaves people some time to complete their sign-in process)
#
module AbandonedThreadsJob
  def self.perform(params = {:remove => :orphaned, :reclaim => true})
    if params[:reclaim]
      reclaim(params.reject{|k,v| [:reclaim, :remove].include?(k) })
    end
    clean(params.reject{|k,v| k == :reclaim })
  end

  def self.clean(params = {:remove => :orphaned})
    destr = to_destroy(params)
    destr.destroy_all
    OCLogger.log "#{destr.count} letters destroyed."
  end

  def self.reclaim(params = {})
    recl = to_send(params)
    recl.map do |letter|
      sender = get_sender_for(letter)
      letter.update_attributes(:status => "START", :direction => "TO_RECIPIENT")
      letter.formageddon_thread.update_attributes(:formageddon_sender => sender)
      letter.delay.send_letter
    end
    OCLogger.log "#{recl.count} letters sent."
  end

  def self.dry_run(params = {:remove => :orphaned})
    destr = to_destroy(params.reject{|k,v| k == :reclaim })
    recl = to_send(params.reject{|k,v| [:reclaim, :remove].include?(k) })
    OCLogger.log "#{destr.count} letters to be destroyed, #{recl.count} to send."
    nil
  end

  protected

  def self.to_send(params = {})
    relation = Formageddon::FormageddonLetter.where(:status => nil)
    relation = time_window(relation, params)

    letter_ids = Set.new
    relation.each do |l|
      sender = get_sender_for(l)
      if sender.present? && sender.status == Authable::STATUSES[:active]
        letter_ids << l.id
      end
    end
    relation.where(:id => letter_ids.to_a)
  end

  def self.to_destroy(params)
    relation = Formageddon::FormageddonLetter.where(:status => nil)
    relation = time_window(relation, params)

    letter_ids = Set.new
    params[:remove] = [params[:remove]] if params[:remove].is_a?(Symbol)
    if params[:remove].include? :orphaned
      relation.each{|l| letter_ids << l.id if get_sender_for(l).nil? }
    end
    if params[:remove].include? :inactive
      relation.each do |l|
        sender = get_sender_for(l)
        letter_ids << l.id if (
          sender.present? &&
          (sender.status <= Authable::STATUSES[:unconfirmed] ||
           sender.status >= Authable::STATUSES[:deleted]
          )
        )
      end
    end

    relation = relation.where(:id => letter_ids.to_a) if params[:remove].present?
  end

  def self.time_window(relation, params = {})
    if params[:since].present?
      relation = relation.where("created_at > ?", params[:since])
    end

    if params[:older_than].present? && params[:older_than].is_a?(Fixnum)
      relation = relation.where("created_at < ?", params[:older_than].ago)
    end
    relation
  end

  def self.get_sender_for(letter)
    thread = letter.formageddon_thread
    sender = User.find_by_email(thread.sender_email)
  end
end
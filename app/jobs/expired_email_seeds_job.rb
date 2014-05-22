module ExpiredEmailSeedsJob
  # Email seeds expire in two ways. Either they are abandoned by the sender or
  # they have been confirmed and converted into ContactCongressLetters. The
  # seeds for the latter case are retained for auditing. This job cleans up
  # both cases. We use a single expiration period for both situations.

  def self.perform (options = {:dryrun => false})
    expiration = Settings.email_congress_seed_expiration.days.ago
    OCLogger.log "Finding seeds last updated before #{expiration}"
    seeds = EmailCongressLetterSeed.where(['updated_at < ?', expiration])
    if seeds.count == 0
      OCLogger.log "No email seeds to destroy."
      return
    end

    seeds.each do |s|
      begin
        email = Postmark::Mitt.new(s.raw_source)

        if options[:dryrun] == false
          OCLogger.log "Destroying seed ##{s.id} from #{s.sender_email} to #{email.to_email}"
          s.destroy
        else
          OCLogger.log "Would destroy seed ##{s.id} from #{s.sender_email} to #{email.to_email}"
        end
      rescue => e
        OCLogger.log "Failed to destroy seed ##{s.id} because: #{e}"
      end
    end
  end
end

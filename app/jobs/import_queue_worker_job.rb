require 'beanstalk-client'

module ImportQueueWorkerJob
  def self.perform ()
    begin
      beanstalk = Beanstalk::Pool.new(Settings.beanstalk_servers)
      beanstalk.watch(Settings.unitedstates_import_queue)
    rescue Beanstalk::NotConnected
      Raven.capture_message "Beanstalk connection failed",
        tags: {
          type: 'import'
        }
      OCLogger.log "Failed to connect to Beanstalk. Check your application settings."
      return
    end

    begin
      trap('SIGTERM') do
        OCLogger.log "Caught SIGTERM, shutting down import:worker task."
        raise Interrupt
      end

      OCLogger.log "Monitoring '#{Settings.unitedstates_import_queue}' beanstalk queue for import tasks."
      loop do
        job = beanstalk.reserve
        begin
          OCLogger.log "Processing import task: #{job.body}"
          import_job = JSON.parse(job.body, :object_class => HashWithIndifferentAccess)
          if import_job[:bill_id]
            ImportBillsJob.perform(import_job)
          elsif import_job[:amendment_id]
            ImportAmendmentsJob.perform(import_job)
          elsif import_job[:vote_id]
            ImportRollCallsJob.perform(import_job)
          end
          job.delete

        rescue JSON::ParserError => e
          Raven.capture_message "Failed to parse import job as JSON: '#{import_job}': #{e}",
            tags: {
              type: 'import'
            }
          OCLogger.log "Failed to parse import job as JSON: '#{import_job}': #{e}"
          job.bury

        rescue StandardError => e
          Raven.capture_message "Error while processing import job: '#{import_job}': #{e}",
            tags: {
              type: 'import'
            }
          OCLogger.log "Error while processing import job: '#{import_job}': #{e}"
          job.bury
        rescue Exception => e
          Raven.capture_exception e,
            tags: {
              type: 'import'
            }
        end
      end

    rescue Beanstalk::NotConnected
      Raven.capture_message "Lost connection to Beanstalk",
        tags: {
          type: 'import'
        }
      OCLogger.log "Lost connection to Beanstalk. Exiting."

    rescue Interrupt
      # Ignore
    end
  end
end

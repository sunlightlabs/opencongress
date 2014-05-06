require 'email_subscription_updated_service'

module EmailListable
  extend ActiveSupport::Concern

  module ClassMethods
    def update_email_subscription_when_changed(user, props)
      after_save Proc.new{
        binding.pry
        EmailSubscriptionUpdatedService.new(user)
      }, :if => Proc.new{
        props.map{|p| return true if send(:"#{p}_changed?") }.compact.any?
      }
    end
  end
end
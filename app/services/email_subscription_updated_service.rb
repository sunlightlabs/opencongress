require 'blue_state_digital'

class EmailSubscriptionUpdatedService

  LISTS = {
    :opencongress_mail => Settings.bsd_group_id,
    :partner_mail => Settings.bsd_affiliate_group_id
  }

  def initialize(user)
    LISTS.each_with_index do |opt, list|
      if user.user_options.send(:"#{opt.to_s}?")
        if user.email_changed? && !user.user_options.send(:"#{opt.to_s}_changed?")
          BlueStateDigital.remove_from_group_by_email(user.email_was, list)
        end
        BlueStateDigital.add_to_group_by_email(user.email, list)
      elsif user.user_options.send(:"#{opt.to_s}_changed?")
        if user.email_changed?
          BlueStateDigital.remove_from_group_by_email(user.email_was, list)
        else
          BlueStateDigital.remove_from_group_by_email(user.email, list)
        end
      end
    end
  end
end
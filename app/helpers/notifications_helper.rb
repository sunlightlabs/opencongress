module NotificationsHelper

  NOTIFICATION_BASE_DIRECTORY = 'notifications'

  def distributors_with_includes(distributors)
    distributors.includes(:notification_aggregate, :notification_aggregate => :activities)
  end

  def na_activities_with_includes(na)
    na.activities.includes(:trackable)
  end

  def unique_activities(activities)
    activities.to_ary.uniq{|i| i.owner_id }
  end

  def render_base(distributor)
    split = distributor.notification_aggregate.activity_key.split('.')
    model, action = split[0], split[1]
    render "#{NOTIFICATION_BASE_DIRECTORY}/#{model}/base", :na => distributor.notification_aggregate
  end

  def render_headline(na)
    split = na.activity_key.split('.')
    model, action = split[0], split[1]
    render "#{NOTIFICATION_BASE_DIRECTORY}/#{model}/#{action}/headline", :na => na
  end

  def render_body(activity)
    split = activity.key.split('.')
    model, action = split[0], split[1]
    render "#{NOTIFICATION_BASE_DIRECTORY}/#{model}/#{action}/body", :activity => activity
  end

  class BillAction

    def self.render_create_body(activity)
      split = activity.key.split('.')
      model, action = split[0], split[1]
      render "#{NOTIFICATION_BASE_DIRECTORY}/#{model}/#{action}/type/#{activity.trackable.action_type}", :bill_action => activity.trackable
    end

    def self.render_create_headline(na)
      na.activity_owner.to_email_subject
    end

  end

end
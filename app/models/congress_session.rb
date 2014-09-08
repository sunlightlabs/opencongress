# == Schema Information
#
# Table name: congress_sessions
#
#  id            :integer          not null, primary key
#  chamber       :string(255)
#  date          :date
#  is_in_session :boolean
#  created_at    :datetime
#  updated_at    :datetime
#

class CongressSession < OpenCongressModel

  # TODO: This model is all sorts of crazy. This needs a lot of TLC.

  def CongressSession.house_session(date=nil)
    date = Date.today if date.nil?
    where("date >=? AND chamber='house' AND is_in_session='t'", date).first
  end

  def CongressSession.senate_session(date=nil)
    date = Date.today if date.nil?
    where("date >=? AND chamber='senate' AND is_in_session='t'", date).first
  end

  def CongressSession.recess_session
    where(chamber:'recess').first
  end

  def self.sessions(date=nil)
    { :house_session => CongressSession.house_session(date), :senate_session => CongressSession.senate_session(date), :recess_session => CongressSession.recess_session }
  end

  def today?
    date == Date.today
  end

  def for_date?(date_cmp)
    date == date_cmp
  end
end

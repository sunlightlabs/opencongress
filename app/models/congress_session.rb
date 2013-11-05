class CongressSession < ActiveRecord::Base
  def CongressSession.house_session(date=nil)
    date = Date.today if date.nil?
    find(:first, :conditions => ["date >=? AND chamber='house' AND is_in_session='t'", date])
  end

  def CongressSession.senate_session(date=nil)
    date = Date.today if date.nil?
    find(:first, :conditions => ["date >=? AND chamber='senate' AND is_in_session='t'", date])
  end

  def CongressSession.recess_session
    find(:first, :conditions => "chamber='recess'")
  end

  def self.sessions(date=nil)
    { :house_session => CongressSession.house_session(date), :senate_session => CongressSession.senate_session(date), :recess_session => CongressSession.recess_session }
  end

  def today?
    date == Date.today
  end
end

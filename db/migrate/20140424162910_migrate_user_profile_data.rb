##
# This migration moves data from the old User model to UserOptions and UserProfile
#
# Code changes must accompany to define UserOptions and UserProfiles classes, but
# code delegating user methods to these new models must not be included.
#

require 'full-name-splitter'

class MigrateUserProfileData < ActiveRecord::Migration
  def self.up
    execute <<-EOQ
      insert into user_profiles
        (user_id, first_name, last_name, website, about, main_picture, small_picture, zipcode, zip_four)
        select id, full_name, full_name, homepage, about, main_picture, small_picture, zipcode, zip_four
        from users;
    EOQ

    execute <<-EOQ
      insert into user_options
        (user_id, comment_threshold, opencongress_mail, partner_mail, feed_key)
        select id, default_filter, mailing, partner_mailing, feed_key
        from users;
    EOQ

    User.where("full_name is not NULL").find_each do |u|
      first, last = FullNameSplitter.split(u.full_name)
      UserProfile.where(:user_id => u.id).update_all(:first_name => first, :last_name => last)
      puts "Set #{u.email} to #{last}, #{first}."
    end
  end

  def self.down
    execute <<-EOQ
      update users
      set
        users.full_name       = CONCAT(user_profiles.first_name, ' ', user_profile.last_name)
        users.homepage        = user_profiles.website
        users.about           = user_profiles.about
        users.main_picture    = user_profiles.main_picture
        users.small_picture   = user_profiles.small_picture
        users.zipcode         = user_profiles.zipcode
        users.zip_four        = user_profiles.zip_four
        users.default_filter  = user_options.comment_threashold
        users.mailing         = user_options.opencongress_mail
        users.partner_mailing = user_options.partner_mail
        users.feed_key        = user_options.feed_key
      inner join user_options on users.id = user_options.user_id
      inner join user_profiles on users.id = user_profiles.user_id;
    EOQ

    execute "update users set accept_terms = TRUE where users.status 1;"
  end
end

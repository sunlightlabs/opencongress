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

    UserProfile.where("first_name is not NULL").find_each do |up|
      first, last = FullNameSplitter.split(up.first_name)
      UserProfile.includes(:user).where(:id => up.id).update_all(:first_name => first, :last_name => last)
      puts "Set #{up.user.email} to #{last}, #{first}."
    end
  end

  def self.down
    # NOTE: This is probably going to take like 3 years to run, just consider this irreversable.
    execute <<-EOQ
      update users
      set
        full_name       = CONCAT(up.first_name, ' ', up.last_name),
        homepage        = up.website,
        about           = up.about,
        main_picture    = up.main_picture,
        small_picture   = up.small_picture,
        zipcode         = up.zipcode,
        zip_four        = up.zip_four,
        default_filter  = uo.comment_threshold,
        mailing         = uo.opencongress_mail,
        partner_mailing = uo.partner_mail,
        feed_key        = uo.feed_key
      from users u
      inner join user_options uo on u.id = uo.user_id
      inner join user_profiles up on u.id = up.user_id;
    EOQ

    execute "update users set accept_terms = TRUE where users.status 1;"
  end
end

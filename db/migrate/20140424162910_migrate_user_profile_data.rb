##
# This migration moves data from the old User model to UserOptions and UserProfile
#
# Code changes must accompany to define UserOptions and UserProfiles classes, but
# code delegating user methods to these new models must not be included.
#

require 'full-name-splitter'

class MigrateUserProfileData < ActiveRecord::Migration
  def self.up
    puts "Hang in there, this one is gonna touch every User instance"

    User.all.each do |u|
      next if u.email.nil?
      first_name, last_name = FullNameSplitter.split(u.full_name)
      u.build_user_profile(
        :first_name => first_name,
        :last_name => last_name,
        :website => u.homepage,
        :about => u.about,
        :main_picture => u.main_picture,
        :small_picture => u.small_picture,
        :zipcode => u.zipcode,
        :zip_four => u.zip_four,
      )
      u.build_user_options(
        :comment_threshold => u.default_filter,
        :opencongress_mail => u.mailing,
        :partner_mail => u.partner_mailing,
        :feed_key => u.feed_key
      )
      puts u.email
      u.save!
    end
  end

  def self.down
    puts "Hang in there, this one is gonna touch every User instance"
    User.all.each do |u|
      u.full_name = [u.user_profile.first_name, u.user_profile.last_name].join(" ")
      u.homepage = u.user_profile.website
      u.about = u.user_profile.about
      u.main_picture = u.user_profile.main_picture
      u.small_picture = u.user_profile.small_picture
      u.zipcode = u.user_profile.zipcode
      u.zip_four = u.user_profile.zip_four
      u.default_filter = u.user_options.comment_threshold
      u.mailing = u.user_options.opencongress_mail
      u.partner_mailing = u.user_options.partner_mail
      u.feed_key = u.user_options.feed_key
      if u.status == 1
        u.accept_terms = true # this is safe because every authorized user has accepted the terms
      end
      u.save!
    end
  end
end

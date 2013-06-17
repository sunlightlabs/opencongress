namespace :users do

  def red
    "\e[31m"
  end

  def green
    "\e[32m"
  end

  def color_puts (color, msg)
    if $stdout.tty?
      puts "#{color}#{msg.to_s}\e[0m"
    else
      puts msg.to_s
    end
  end

  desc "Make a user a superuser"
  task :make_superuser => :environment do
    email = ENV['email']
    login = ENV['login']
    if email and login
      color_puts red, "Specify only one of 'email' or 'login'"
      next
    elsif not email and not login
      color_puts red, "Specify one of 'email' or 'login'"
      next
    elsif email
      user = User.find_by_email(email)
      if not user
        color_puts red, "No such user with email #{email}"
        next
      end
    elsif login
      user = User.find_by_login(login)
      if not user
        color_puts red, "No such user with login #{login}"
        next
      end
    end

    role = user.user_role
    role.can_blog = true
    role.can_administer_users = true
    role.can_see_stats = true
    role.can_manage_text = true
    role.can_moderate_articles = true
    role.can_edit_blog_tags = true
    role.name = 'Administrator'
    role.save!
    color_puts green, "User #{user.login} #{user.email} is now a superuser. They can admin all the things."
  end

end


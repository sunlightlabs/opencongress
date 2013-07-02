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

  def lookup_user_from_env
    email = ENV['email']
    login = ENV['login']
    if email and login
      color_puts red, "Specify only one of 'email' or 'login'"
      return nil
    elsif not email and not login
      color_puts red, "Specify one of 'email' or 'login'"
      return nil
    elsif email
      user = User.find_by_email(email)
      if not user
        color_puts red, "No such user with email #{email}"
        return nil
      end
    elsif login
      user = User.find_by_login(login)
      if not user
        color_puts red, "No such user with login #{login}"
        return nil
      end
    end
    return user
  end

  desc "List user roles"
  task :list_roles => :environment do
    roles = UserRole.order(:name).map do |role|
      role.to_hash
    end

    puts roles.to_yaml(:indentation => 2)
  end

  desc "Make a user a superuser"
  task :set_role => :environment do
    user = lookup_user_from_env
    next if user.nil?

    role_name = ENV['role']
    role = UserRole.find_by_name(role_name)
    if role.nil?
      color_puts red, "No such role: #{role_name}"
      next
    end

    user.user_role = role
    user.save!

    color_puts green, "User #{user.login} #{user.email} is now a #{role.name}."
    puts role.to_hash.to_yaml(:indentation => 2)
  end

  desc "Ban a user (by login or email)"
  task :ban => :environment do
    user = lookup_user_from_env
    next if user.nil?

    if user.is_banned?
      color_puts red, "User #{user.login} (#{user.email}) is already banned."
    else
      user.ban!
      color_puts green, "User #{user.login} (#{user.email}) is now banned."
    end
  end

  desc "Unban a user (by email)"
  task :unban => :environment do
    user = lookup_user_from_env
    next if user.nil?

    if user.is_banned?
      user.unban!
      color_puts green, "User #{user.login} (#{user.email}) is no longer banned."
    else
      color_puts red, "User #{user.login} (#{user.email}) is not banned."
    end
  end
end


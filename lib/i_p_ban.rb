class IPBan

  SYNTAX = HashWithIndifferentAccess.new(
    :apache => "%s b",
    :nginx => "deny %s;"
  )

  def initialize
  end

  class << self
    def create_by_ip(ipaddr)
      gots = false
      file = File.open(Settings.ban_file, 'r+')
      file.each do |line|
        if line =~ /#{formatted ipaddr}/
          gots = true
          return false
        end
      end

      if gots == false
        file.puts formatted(ipaddr)
        file.close
      end
      true
    end

    def delete_by_ip(ipaddr)
      new_contents = ""
      File.readlines(Settings.ban_file).each do |f|
        unless f =~ /#{formatted ipaddr}/
          new_contents << f
        end
      end
      file = File.open(Settings.ban_file, 'w')
      file.puts new_contents
      file.close
    end

    def formatted(ipaddr)
      format(SYNTAX.fetch(Settings.ban_format, :apache), ipaddr)
    end
  end
end
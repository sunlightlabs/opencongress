module FileUtils

  # Iteratively creates a directory and all subdirectories if they don't exist.
  #
  # @param dir_path [String] directory path, i.e. /src_data/etc/etc/etc/etc/
  def self.mkdir_p_if_nonexistent(dir_path)

    split_dirname = dir_path.split('/')
    abs_path = split_dirname[0] == '' ? '/' : Dir.pwd + '/'

    split_dirname.each do |path|
      abs_path += path + '/'
      FileUtils.mkdir_p(abs_path) unless File.directory?(abs_path)
    end

  end

end
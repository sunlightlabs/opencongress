module SystemUtils
  def self.clone_or_update (url, dest)
    if Dir.exist? dest
      cmd = "cd #{dest} && git pull"
      OCLogger.log cmd
      system cmd
    else
      mkdir_guard dest
      cmd = "git clone #{url} #{dest}"
      OCLogger.log cmd
      system cmd
    end
  end
end

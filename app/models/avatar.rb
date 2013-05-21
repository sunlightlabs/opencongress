class Avatar
  require 'RMagick'

  DEFAULT_UPLOAD_PATH = "#{Rails.root.to_s}/public/images/users/"
  DEFAULT_SIZES = { :m => [120, 120], :s => [80, 80] }
  DEFAULT_QUALITY = 80

  attr_accessor :upload_path, :blob, :name, :quality

  def initialize(img, options=nil)
    self.blob = img
    self.name = options[:name] || (raise "Picture instances must have a name")
    self.upload_path ||= DEFAULT_UPLOAD_PATH
    self.quality ||= DEFAULT_QUALITY
    mkdir_p(upload_path)
  end

  def crop(maxwidth, maxheight)
    aspectratio = maxwidth.to_f / maxheight.to_f
    pic = Magick::Image.from_blob(blob).first
    imgwidth = pic.columns
    imgheight = pic.rows
    imgratio = imgwidth.to_f / imgheight.to_f
    (imgratio > aspectratio) ? scaleratio = maxwidth.to_f / imgwidth : scaleratio = maxheight.to_f / imgheight
    thumb = pic.thumbnail(scaleratio)
    thumb.to_blob
  end

  def get_filenames(sizes=nil)
    sizes ||= DEFAULT_SIZES
    sizes.keys.collect do |s|
      "#{name}_#{s}.jpg"
    end
  end

  def create_sizes!(sizes=nil)
    sizes ||= DEFAULT_SIZES
    sizes.map do |s, dims|
      pic = Magick::Image.from_blob(crop(*dims)).first
      pic.write("#{upload_path}/#{name}_#{s}.jpg") { self.quality = quality }
    end
    get_filenames(sizes)
  end
end
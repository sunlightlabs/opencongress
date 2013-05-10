require 'unicode_utils/nfkd'

class String
  def unaccent
    UnicodeUtils.nfkd(self).encode('US-ASCII', :undef => :replace,
      :invalid => :replace, :replace => '')
  end
end
module EmailCongress

  class ProfileProxy
    include ActiveModel::Naming
    include ActiveModel::Conversion
    include ActiveModel::Validations

    @@ATTRS = [:email, :accept_tos, :title, :first_name, :last_name,
               :mobile_phone, :street_address, :street_address_2, :city,
               :state, :zipcode, :zip_four]
    attr_accessor(*@@ATTRS)

    validates_acceptance_of :accept_tos, :allow_nil => true, :accept => true
    validates_presence_of :first_name
    validates_presence_of :last_name
    validates_presence_of :street_address
    validates_presence_of :city
    validates_presence_of :state
    validates_presence_of :zipcode
    validates_presence_of :email
    validates_presence_of :mobile_phone

    def initialize (src=nil)
      @errors = ActiveModel::Errors.new(self)
      unless src.nil?
        copy_from(src)
      end
    end

    def attributes
      @@ATTRS.clone
    end

    def attributes_hash
      pairs = @@ATTRS.map{ |attr| [attr, self.send(attr)] }
      Hash[pairs]
    end

    def persisted?
      # Satisfied ActiveModel::Conversion
      false
    end

    def full_zipcode
      "#{self.zipcode}-#{self.zip_four}".sub(/-$/, '')
    end

    def full_name
      [self.first_name, self.last_name].join(' ').strip
    end

    def copy_from (src)
      init_method = "copy_from_#{src.class.name.downcase}"
      if self.respond_to?(init_method)
        self.send(init_method, src)
      else
        raise "Cannot initialize ProfileProxy from #{src.class.name} object."
      end
    end

    def copy_to (dst)
      persist_method = "copy_to_#{dst.class.name.downcase}"
      if self.respond_to?(persist_method)
        self.send(persist_method, dst)
      else
        raise "ProfileProxy cannot persist values to a #{dst.class.name} object."
      end
    end

    def merge (other)
      merged = ProfileProxy.new
      # Existing values take precedence, so copy in reverse order.
      other.copy_to_generic_dest(merged)
      self.copy_to_generic_dest(merged)
      # Handle TOS specially since the user only has to accept the TOS once
      merged.accept_tos = [self.accept_tos, other.accept_tos].any?
      merged
    end

    def copy_from_mapped_attributes (attr_map, src)
      # TODO: can probably be removed
      attr_map.each do |from_attr, to_attr|
        existing_value = self.send(to_attr)
        new_value = src.send(from_attr)
        if !new_value.nil? && new_value != existing_value
          self.send("#{to_attr}=", src.send(reader))
        end
      end
    end

    def copy_from_generic_source (src)
      self.attributes_hash.each do |attr_name, existing_value|
        if existing_value.blank? && src.respond_to?(attr_name)
          value = src.send(attr_name)
          if !value.nil?
            self.send("#{attr_name}=", value)
          end
        end
      end
    end

    def copy_to_generic_dest (dst)
      self.attributes_hash.each do |attr_name, value|
        writer = "#{attr_name}="
        if dst.respond_to?(writer) && !value.blank?
          puts "#{writer}#{value}"
          dst.send(writer, value)
        end
      end
    end

    def copy_from_emailcongressletterseed (src)
      @@ATTRS.each do |f|
        reader = "sender_#{f}"
        writer = "#{f}="
        if src.respond_to?(reader) && self.respond_to?(writer)
          self.send(writer, src.send(reader))
        end
      end
    end

    def copy_to_emailcongressletterseed (dst)
      @@ATTRS.each do |f|
        reader = "#{f}"
        writer = "sender_#{f}="
        if self.respond_to?(reader) && dst.respond_to?(writer)
          dst.send(writer, self.send(reader))
        end
      end
    end

    def copy_to_user (dst)
      copy_to_generic_dest(dst)
      dst.full_name = self.full_name
      if self.accept_tos == true
        dst.accept_tos = '1'
        dst.accepted_tos_at ||= Time.now
      else
        dst.accept_tos = '2'
        dst.accepted_tos_at = nil
      end
    end

    def copy_from_user (src)
      # will handle :zipcode, :zip_four, :state, :email
      copy_from_generic_source(src)
      name_parts = src.full_name.split(/ /, 2)
      self.first_name = name_parts.first
      self.last_name = name_parts.second
      self.accept_tos = src.accepted_tos?
    end

    def copy_from_openstruct (src)
      copy_from_generic_source(src)
    end

    def copy_to_openstruct (dst)
      copy_to_generic_dest(dst)
    end
  end

  class << self
    def localpart_pattern
      /(Rep|Sen)([-A-Za-z0-9]+)/i
    end

    def parse_localpart (localpart)
      m = localpart_pattern.match(localpart)
      return nil if m.nil?
      { :title => m.captures[0].downcase,
        :subdomain => m.captures[1].downcase }
    end

    def websites_for_title_and_subdomain (title, subdomain)
      duplicate_with_trailing_slash = lambda { |url| [url, "#{url}/"] }
      urls = case title.downcase
      when "rep"
        ["http://#{subdomain}.house.gov",
         "http://www.#{subdomain}.house.gov",
         "http://www.house.gov/#{subdomain}"]
      when "sen"
        ["http://#{subdomain}.senate.gov",
         "http://www.#{subdomain}.senate.gov",
         "http://www.senate.gov/#{subdomain}"]
      end
      urls.flat_map(&duplicate_with_trailing_slash)
    end

    def expand_special_addresses (addresses)
      # TODO: Implement this
      addresses
    end

    def congressmembers_for_address (address, date=Date.today)
      # Maps the given address to a set of Person models.
      # Not intended to be called from client code.
      begin
        addr = Mail::Address.new(address)
      rescue Mail::Field::ParseError
        return []
      end
      return [] if Settings.email_congress_domains.include?(addr.domain)
      addr1 = parse_localpart(addr.local)
      websites = websites_for_title_and_subdomain(addr1[:title], addr1[:subdomain])

      roles = Role.on_date(date).where(:url => websites).to_a
      people = roles.map(&:person).to_a
      if date == Date.today
        people += Person.on_date(date).where(:website => websites).to_a
      end
      people.uniq!
    end

    def congressmember_for_address (address, date=Date.today)
      # Maps the given address to a single Person model. Raises a
      # RuntimeError in the case of multiple matches. Returns nil
      # in the case of no matches.
      members = congressmembers_for_address(address, date)
      if members.length > 1
        raise "Multiple Person models for the same address: #{address} as of #{date}"
      end
      members.first
    end

    def profile_is_complete (profile)
      profileish = ProfileProxy.new(profile)
      profileish.valid?
    end
  end
end


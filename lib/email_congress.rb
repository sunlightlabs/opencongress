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
      # TODO: Put to use to copy to formageddonthread objects
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
      /(Rep|Sen)[.]?([-A-Za-z0-9]+)/i
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

    def email_address_for_website (website)
      pattern = /^(?:www[.])?([a-z0-9]+)[.](house|senate)[.]gov$/i
      url = URI.parse(website)
      return nil if url.host.nil?
      match = pattern.match(url.host.downcase)
      return nil if match.nil?
      nameish, chamber = match.captures
      return "#{chamber.first(3).capitalize}.#{nameish.capitalize}"
    end

    def email_address_for_person (person)
      return nil if person.website.blank?
      email_address_for_website(person.website)
    end

    def expand_special_addresses (sender_user, addresses)
      return addresses if @sender_user.nil?
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
      return [] unless Settings.email_congress_domains.include?(addr.domain)
      addr1 = parse_localpart(addr.local)
      websites = websites_for_title_and_subdomain(addr1[:title], addr1[:subdomain])

      roles = Role.on_date(date).where(:url => websites).to_a
      people = roles.map(&:person).to_a
      if date == Date.today
        people += Person.on_date(date).where(:website => websites).to_a
      end
      people.uniq
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

    def seed_for_postmark_object (obj)
      if obj.is_a?(String)
        email = Postmark::Mitt.new(JSON.load(json))
      elsif obj.is_a?(Hash)
        email = Postmark::Mitt.new(JSON.dump(obj))
      elsif obj.is_a?(Postmark::Mitt)
        email = obj
      else
        raise "Unable to construct EmailCongressLetterSeed for #{json.class.name}"
      end

      seed = EmailCongressLetterSeed.new
      seed.raw_source = email.raw
      seed.sender_email = email.from_email
      seed.email_subject = email.subject
      seed.email_body = email.text_body
      seed.save!
      return seed
    end

    def reify_as_formageddon_letter (seed)
      # Creates a FormageddonLetter instance, not yet associated to a thread.
      letter = Formageddon::FormageddonLetter.new
      letter.subject = seed.email_subject
      letter.message = email_body
      letter.direction = 'TO_RECIPIENT'
      letter.issue_area = nil   # This will be set if required by the contact form.
      letter.status = nil  # This field captures errors. No errors at the outset.
      letter.fax_id = nil  # This will be set if we fall back to faxing.
      letter.save!
      return letter
    end

    def reify_as_formageddon_thread (seed, sender, rcpt)
      # Creates a FormageddonThread instance, not yet associated to a
      # ContactCongressFormageddonThread
      seed_profile = ProfileProxy.new(seed)
      thread = Formageddon::FormageddonThread.new
      seed_profile.copy_to(thread)
      thread.formageddon_recipient = rcpt
      thread.formageddon_sender = sender
      thread.privacy = 'PRIVATE'
      thread.save!
      return thread
    end

    def reify_for_contact_congress (sender, seed, recipients)
      # Establishes ContactCongress object graph, returning the
      # ContactCongressLetter tying it all together.

      throw "Seed ##{seed.id} (#{seed.confirmation_code}) is not confirmed." if !seed.confirmed?

      ActiveRecord::Base.transaction do
        ccl_threads = recipient.map do |rcpt|
          thread = reify_as_formageddon_thread(sender, seed, rcpt)
          letter = reify_as_formageddon_letter(sender, seed)
          thread.formageddon_letters.add(letter)

          ccl_thread = ContactCongressLettersFormageddonThread.new
          ccl_thread.formageddon_thread = thread
          ccl_thread.save!

          ccl_thread
        end

        ccl_letter = ContactCongressLetter.new
        ccl_letter.user = sender
        ccl_letter.disposition = ''   # Leave blank for now. Do sentiment analysis in the future?
        ccl_letter.contactable = nil  # Don't associate with a contactable topic, e.g. Bill.
        ccl_letter.is_public = false  # Private because we cannot provide an up-front warning before the user sends an email.
        ccl_letter.contact_congress_letters_formageddon_threads << ccl_threads
        ccl_letter.save!

        return ccl_letter
      end
    end
  end
end


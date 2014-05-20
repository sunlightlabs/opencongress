module NANP
  def self.special_numbers_pattern
    /^(011|01|00|0|101\d{4}|[23456789]11|(1\d{3})?958\d{4}|1\d{3}5551212|[*](11)?(51|57|66|67|69|70|71|74|82))$/
  end

  class Parser
    def parse (numstr)
      @numstr = numstr.strip
      @offset = 0

      if @numstr =~ NANP.special_numbers_pattern
        return @numstr
      end

      extension
      country_code
      eat_junk
      eat_long_distance_code
      eat_junk
      area_code
      eat_junk
      exchange_code
      eat_junk
      subscriber_number
      eat_junk
      assert_done

      return [@country_code, @area_code, @exchange_code, @subscriber_number, @extension]
    end

    def account_for (parsed)
      @offset += parsed.length
      return parsed
    end

    def raise_parse_error (error)
      raise "#{error} at position #{@offset}"
    end

    def eat_junk
      while (@numstr.length > 0) && !(@numstr.first =~ /\d/)
        account_for(@numstr.slice!(0, 1))
      end
    end

    def assert_done
      if @numstr.length > 0
        if @extension.nil?
          raise_parse_error "Unexpected characters after the subscriber number"
        else
          raise_parse_error "Unexpected characters before the extension"
        end
      end
    end

    def extension
      extension_count = @numstr.count('x')
      if extension_count > 1
        raise "Multiple extensions specified"
      elsif extension_count == 1
        @numstr, @extension = @numstr.split(/x/, 2)
      end
      return nil
    end

    def country_code
      if @numstr.first == '+'
        if @numstr.first(2) == '+1'
          @country_code = @numstr.slice!(0, 2)
          account_for(@country_code)
        else
          raise "Unrecognized country code: #{@numstr.first(2)}"
        end
      end
    end

    def eat_long_distance_code
      if @numstr.first == '1'
        account_for(@numstr.slice!(0, 1))
      end
    end

    def area_code
      if @numstr.length < 3
        raise_parse_error "Expected 3-digit area code"
      elsif @numstr.gsub(/\D/, '').length > 7
        account_for(@area_code = @numstr.slice!(0, 3))
      end
    end

    def exchange_code
      if @numstr.length < 3
        raise_parse_error "Expected 3-digit exchange code"
      end
      account_for(@exchange_code = @numstr.slice!(0, 3))
    end

    def subscriber_number
      if @numstr.length < 4
        raise_parse_error "Expected 4-digit subscriber code"
      end
      account_for(@subscriber_number = @numstr.slice!(0, 4))
    end
  end

  class PhoneNumber
    attr_reader :original, :special_number, :error
    attr_reader :country_code, :area_code, :exchange_code, :subscriber_number, :extension

    def initialize (numstr)
      @original = numstr.clone
      begin
        parsed = Parser.new.parse(numstr)
        if parsed.is_a?(String)
          @special_number = parsed
        elsif parsed.is_a?(Array) and parsed.length == 5
          @country_code, @area_code, @exchange_code, @subscriber_number, @extension = parsed
        else
          raise "Unrecognized return value from NANP::Parser#parse"
        end
      rescue => e
        @error = e.to_s
      end
    end

    def international?
      return @country_code
    end

    def reserved?
      valid? && @area_code[1] == @area_code[2]
    end

    def special?
      !@special_number.nil?
    end

    def local?
      valid? && @area_code.nil?
    end

    def valid?
      @error.nil?
    end

    def to_s
      return @special_number unless @special_number.nil?

      parts = [country_code, area_code, exchange_code, subscriber_number]
      unless @extension.nil?
        parts << 'x'
        parts << extension
      end
      return parts.join('')
    end
  end
end

module UnitedStates

  CONGRESS = Settings.default_congress
  IMPORT_UNTIL = Settings.default_import_until

  module ImportGuard
    def self.extended(base)
      object = base.name.underscore.split('/').last.singularize
      base.const_set(:IMPORT_UNTIL, (::Settings.send("#{object}_import_until".to_sym) rescue Settings.default_import_until))
      base.const_set(:CONGRESS, (::Settings.send("#{object}_congress".to_sym) rescue Settings.default_congress))
      base.class_eval do
        def import_expired? ()
          Date.today > (Date.parse(self::IMPORT_UNTIL) rescue self::IMPORT_UNTIL)
        end
      end
    end
  end
end

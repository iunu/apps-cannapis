module Common
  class Utils
    def self.normalize_barcode(label)
      self.replace(label, '-split')
    end

    def self.normalize_zone_name(name)
      self.replace(name, /\s*\[.*?\]/)
    end

    private

    def self.replace(str, regex, replacement = '')
      str&.gsub(regex, replacement)&.strip
    end
  end
end

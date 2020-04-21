module Common
  module Logging
    def log(msg, level = :info)
      logger.send(level, "[#{self.class.name}] #{msg}")
    end

    def logger
      @logger ||= Rails.logger
    end
  end
end

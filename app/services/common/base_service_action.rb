module Common
  class BaseServiceAction
    class TransactionAlreadyExecuted < StandardError; end
    class ServiceActionFailure < StandardError; end

    def self.call(*args, &block)
      instance = new(*args, &block)
      instance.run

      instance.result
    rescue ServiceActionFailure => e
      instance.result
    end

    attr_accessor :result, :integration, :transaction

    def initialize(*)
      @logger = Rails.logger
    end

    def run(*args)
      before
      @result = call(*args)
      after
    rescue TransactionAlreadyExecuted
      log("Success: transaction previously performed. #{transaction.inspect}", :error)
      fail!(transaction)
    end

    def action_label
      self.class.name.underscore.split('/').last.upcase
    end

    protected

    def before
      raise TransactionAlreadyExecuted if transaction.success

      @integration.account.refresh_token_if_needed
    end

    def call
      raise 'You must implemented +call+ in your service class'
    end

    def after; end

    def fail!(result = nil, exception: nil)
      @result = result
      raise ServiceActionFailure.new(exception&.inspect)
    end

    def requeue!(exception: nil)
      raise ScheduledJob::RetryableError.new(exception&.message, original: exception)
    end

    def provider_label
      self.class.name.underscore.split('_').first.upcase
    end

    def log(msg, level = :info)
      @logger.send(level, "[#{provider_label}_#{action_label}] #{msg}")
    end
  end
end

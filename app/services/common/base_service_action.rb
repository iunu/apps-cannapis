module Common
  class BaseServiceAction
    class TransactionAlreadyExecuted < StandardError; end
    class ServiceActionFailure < StandardError; end

    def self.call(*args, &block)
      instance = new(*args, &block)
      instance.run

      instance.result
    rescue ServiceActionFailure
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
    rescue TransactionAlreadyExecuted => e
      log("Success: transaction previously performed. #{transaction.inspect}", :error)
      fail!(transaction, exception: e)
    end

    protected

    def before
      raise TransactionAlreadyExecuted if transaction.success

      @integration.account.refresh_token_if_needed
    end

    def call
      raise 'You must implement +call+ in your service class'
    end

    def after; end

    def success!
      log("Success: batch ID #{@batch_id}, completion ID #{@completion_id}")

      transaction.success = true
      transaction
    end

    def fail!(result = nil, exception: nil)
      @result = result
      raise ServiceActionFailure, exception&.inspect
    end

    def requeue!(exception: nil)
      raise ScheduledJob::RetryableError.new(exception&.message, original: exception)
    end

    def log(msg, level = :info)
      @logger.send(level, "[#{self.class.name}] #{msg}")
    end
  end
end

require_relative './logging'

module Common
  class BaseServiceAction
    include Common::Logging

    DEFAULT_RUN_MODE = :later

    def self.call(*args, &block)
      instance = new(*args, &block)
      instance.run

      instance.result
    rescue ServiceActionFailure
      instance.result
    end

    def self.run_mode(mode = nil)
      @mode = mode if mode.present?
      @mode || DEFAULT_RUN_MODE
    end

    attr_accessor :result, :integration, :transaction

    def run(*args)
      before
      @result = process_completion(*args)
      after
    rescue TransactionAlreadyExecuted => e
      log("Success: transaction previously performed. #{transaction.inspect}", :error)
      fail!(transaction, exception: e)
    end

    protected

    def process_completion(*args)
      case completion_status
      when 'active', '', nil
        call(*args)
      when 'removed'
        revert(*args)
      else
        raise ServiceActionFailure, "Unexpected completion state: #{completion_status}"
      end
    end

    def before
      raise TransactionAlreadyExecuted if transaction.success

      @integration.account.refresh_token_if_needed
    end

    def call
      raise 'You must implement +call+ in your service class'
    end

    # override this in a subclass to handle completion reversion
    def revert
      log("WARNING: batch ID #{@batch_id} completion ID #{@completion_id} was reverted on portal but not handled by the integration server", :warn)
    end

    def after; end

    def success!
      log("Success: batch ID #{@batch_id}, completion ID #{@completion_id}")

      transaction.update(success: true)
      transaction
    end

    def fail!(result = nil, exception: nil)
      @result = result
      raise ServiceActionFailure, exception&.inspect
    end

    def requeue!(exception: nil)
      raise Cannapi::RetryableError.new(exception&.message, original: exception)
    end

    def completion_status
      raise 'override +completion_status+ in subclass'
    end
  end
end

module Common
  module ResourceHandling
    def self.included(base)
      base.send(:extend, ClassMethods)
    end

    module ClassMethods
      def resource_name(name = nil)
        return @resource_name = name if name.present?

        raise 'resource_name must be set in subclass of Resource::Base' if @resource_name.blank?

        @resource_name
      end
    end

    def resource_name
      self.class.resource_name
    end

    private

    def transaction
      @transaction ||= get_transaction(:"resource_#{self.class.resource_name}")
    end

    def resource_present?
      resource_completions.present?
    end

    def resource_completions
      resource_unit_id = @attributes.dig('options', 'resource_unit_id')
      @resource_completions ||= resource_completions_by_unit_id(resource_unit_id)
    end
  end
end

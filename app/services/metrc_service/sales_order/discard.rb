module MetrcService
  module SalesOrder
    class Discard < MetrcService::Base
      def call
        call_metrc(:delete_transfer_template, submitted_transfer_template_id)

        success!
      end

      private

      def submitted_transfer_template_id
        transfer_templates = call_metrc(:list_transfer_templates)
        transfer_template = transfer_templates.find { |template| template['Name'] == batch.arbitrary_id }

        raise InvalidOperation, "could not find a template in Metrc with the name '#{batch.arbitrary_id}'" if transfer_template.nil?

        transfer_template['Id']
      end

      def transaction
        @transaction ||= get_transaction(:discard_sales_order_batch)
      end
    end
  end
end

require 'ostruct'

module MetrcService
  module Package
    class Harvest < MetrcService::Package::Base
      def call
        call_metric(:create_package, @integration.vendor_id, payload, testing?)

        transaction.success = true
        log("Success: batch ID #{@batch_id}, completion ID #{@completion_id}; #{payload}")

        transaction
      end

      private

      def transaction
        @transaction ||= get_transaction(:harvest_package_batch)
      end

      def payload
        [{
          Tag: tag,
          Room: batch.zone.name,
          Item: item_type,
          UnitOfWeight: unit_of_weight,
          PatientLicenseNumber: nil,
          Note: note,
          IsProductionBatch: false,
          ProductionBatchNumber: nil,
          IsTradeSample: false,
          ProductRequiresRemediation: false,
          RemediateProduct: false,
          RemediationMethodId: nil,
          RemediationDate: nil,
          RemediationSteps: nil,
          ActualDate: package_date,
          Ingredients: resources.map do |resource|
            {
              HarvestId: batch.id,
              HarvestName: harvest_name,
              Weight: resource.generated_quantity,
              UnitOfWeight: resource.resource_unit.name
            }
          end
        }]
      end

      def testing?
        seeding_unit.name =~ /Testing Package/
      end

      def tag
        batch.relationships.dig('barcodes', 'data', 0, 'id')
      end

      def item_type
        # TODO: determine item type
        'Buds'
      end

      def unit_of_weight
        validate_resource_units!

        resources.first.resource_unit.name
      end

      def note
        # TODO: retrieve note from completion
      end

      def harvest_name
        batch.arbitrary_id
      end

      def package_date
        @attributes.dig(:start_time)
      end

      def resources
        @resources ||= @attributes.dig(:options, :resources).map do |resource|
          resource[:resource_unit] = get_resource_unit(resource['resource_unit_id'])
          OpenStruct.new(resource)
        end
      end

      def validate_resource_units!
        raise InvalidAttributes, 'UnitOfWeight is not the same for all resources in this package' \
          unless resources.map(&:resource_unit).uniq(&:name).count == 1
      end
    end
  end
end

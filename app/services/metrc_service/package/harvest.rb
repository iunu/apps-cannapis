require 'ostruct'

module MetrcService
  module Package
    class Harvest < MetrcService::Package::Base
      def call
        call_metrc(:create_package, payload, testing?)
        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:harvest_package_batch)
      end

      def payload
        [{
          Tag: tag,
          Location: zone_name,
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
          Ingredients: start_consume_completions.map do |consume|
            harvest_ingredient(consume)
          end
        }]
      end

      def testing?
        seeding_unit.name == 'Testing Package'
      end

      def tag
        batch.relationships.dig('barcodes', 'data', 0, 'id')
      end

      def item_type
        resource_unit_name = resources.first.resource_unit.name

        # try the format: [unit] of [type] - [strain]
        matches = resource_unit_name.match(/^[\w]+ of ([\w\s]+) - [\w\s]+$/)

        # then try the format: [type] - [strain]
        matches = resource_unit_name.match(/^([^\-]+) - [\w\s]+$/) if matches.nil?

        return matches[1] unless matches.nil?

        raise InvalidAttributes,
              "Item type could not be extracted from the resource unit name: #{resource_unit_name}. " \
              "Expected the format '[unit] of [type] - [strain]' or '[type] - [strain]'"
      end

      def zone_name
        get_zone(batch.relationships.dig('zone', 'data', 'id')).name
      end

      def unit_of_weight
        validate_resource_units!

        resources.first.resource_unit.name
      end

      def note
        # TODO: retrieve note from completion
      end

      def harvest_ingredient(consume)
        crop_batch = @artemis.get_facility.batch(consume.options['batch_resource_id'])
        resource_unit = get_resource_unit(consume.options['resource_unit_id'])
        metrc_harvest = lookup_metrc_harvest(crop_batch.arbitrary_id)

        raise DataMismatch, "expected to find a harvest in Metrc named '#{crop_batch.arbitrary_id}' but it does not exist" if metrc_harvest.nil?

        {
          HarvestId: metrc_harvest['Id'],
          HarvestName: crop_batch.arbitrary_id,
          Weight: consume.options['consumed_quantity'],
          UnitOfWeight: resource_unit.name
        }
      end

      def lookup_metrc_harvest(name)
        # TODO: consider date range for lookup - harvest create/finish dates?
        harvests = call_metrc(:list_harvests)
        harvests.find { |harvest| harvest['Name'] == name }
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

      def start_consume_completions
        get_related_completions(:start).map do |start_completion|
          completions = get_child_completions(start_completion.parent_id, filter: { action_type: 'consume' })

          # workaround: API not filtering by parent_id so we do that here
          completions.select { |completion| completion.parent_id == start_completion.parent_id }
        end.flatten
      end

      def validate_resource_units!
        raise InvalidAttributes, 'The package contains resources of multiple types or units. Expected all resources in the package to be the same' \
          unless resources.map(&:resource_unit).uniq(&:name).count == 1
      end
    end
  end
end

module MetrcService
  module Package
    class Start < MetrcService::Package::Base
      run_mode :now

      def call
        flush_upstream_tasks

        create_package
        # finish_harvests

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:start_package_batch)
      end

      def flush_upstream_tasks
        consume_completions.each do |consume|
          source_batch_id = consume.context.dig('source_batch', 'id')
          tasks = upstream_tasks(source_batch_id)
          next if tasks.empty?

          TaskRunner.run(*tasks)
        end
      rescue Cannapi::TaskError => e
        raise UpstreamProcessingError, "Failed to process upstream tasks: #{e.message}"
      end

      def upstream_tasks(source_batch_id)
        @integration
          .schedulers
          .for_today(@integration.timezone)
          .where(batch_id: source_batch_id, facility_id: @facility_id)
      end

      def finish_harvests
        payload = finished_harvest_ids.map do |harvest_id|
          { Id: harvest_id, ActualDate: package_date }
        end

        call_metrc(:finish_harvest, payload) unless payload.empty?
      end

      def consumed_harvest_ids
        @consumed_harvest_ids ||= []
      end

      def finished_harvest_ids
        consumed_harvest_ids.select do |harvest_id|
          harvest = call_metrc(:get_harvest, harvest_id)
          harvest['CurrentWeight'].zero?
        end
      end

      def create_package
        call_metrc(:create_harvest_package, create_package_payload, testing?)
      end

      def create_package_payload
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
          Ingredients: consume_completions.map do |consume|
            harvest_ingredient(consume)
          end
        }]
      end

      def testing?
        batch.arbitrary_id =~ /test/i
      end

      def tag
        batch.relationships.dig('barcodes', 'data', 0, 'id')
      end

      def item_type
        # resource_unit_name = resource_units.name

        # # try the format: [unit] of [type], [strain]
        # type = resource_unit_name[/^[\w]+ of ([\w\s]+), [\w\s]+$/]

        # # then try the format: [type], [strain]
        # type = resource_unit_name[/^([^\-]+), [\w\s]+$/] if type.nil?

        # raise InvalidAttributes,
        #       "Item type could not be extracted from the resource unit name: #{resource_unit_name}. " \
        #       "Expected the format '[unit] of [type], [strain]' or '[type], [strain]'" \
        #       if type.nil?
        #
        # type

        'Flower'
      end

      def zone_name
        get_zone(batch.relationships.dig('zone', 'data', 'id')).name
      end

      def unit_of_weight
        validate_resource_units!

        resource_units.first.unit
      end

      def note
        # TODO: retrieve note from completion
      end

      def harvest_ingredient(consume)
        crop_batch = @artemis.get_facility.batch(consume.context.dig('source_batch', 'id'))
        resource_unit = get_resource_unit(consume.options['resource_unit_id'])
        metrc_harvest = lookup_metrc_harvest(crop_batch.arbitrary_id)

        consumed_harvest_ids << metrc_harvest['Id']

        {
          HarvestId: metrc_harvest['Id'],
          HarvestName: crop_batch.arbitrary_id,
          Weight: consume.options['consumed_quantity'],
          UnitOfWeight: resource_unit.unit
        }
      end

      def package_date
        @attributes.dig(:start_time)
      end

      def resource_units
        @resource_units ||= consume_completions.map do |completion|
          get_resource_unit(completion.options['resource_unit_id'])
        end
      end

      def consume_completions
        batch.completions.select do |completion|
          completion.action_type == 'consume'
        end
      end

      def validate_resource_units!
        raise InvalidAttributes, 'The package contains resources of multiple types or units. Expected all resources in the package to be the same' \
          unless resource_units.uniq(&:unit).count == 1
      end
    end
  end
end

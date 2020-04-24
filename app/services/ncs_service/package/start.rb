module NcsService
  module Package
    class Start < NcsService::Package::Base
      run_mode :now

      def call
        flush_upstream_tasks

        if plant_package
          @transaction_type = :create_plant_package
          create_plant_package
        else
          @transaction_type = :create_product_package
          create_product_package
        end

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(@transaction_type)
      end

      def flush_upstream_tasks
        consume_completions.each do |consume|
          source_batch_id = consume.context.dig('source_batch', 'id')
          tasks = upstream_tasks(source_batch_id)

          if tasks.empty?
            log("Source batch #{source_batch_id} has no pending completions!")
          else
            log("Flushing queued completions for source batch #{source_batch_id}")

            TaskRunner.run(*tasks)
          end
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

      def create_plant_package
        payload = plant_package_payload
        call_ncs(:plant_batch, :create_packages, payload)
      end

      def plant_package_payload
        [{
          PlantBatchName: batch_tag,
          PlantCount: batch.attributes['quantity']&.to_i,
          RoomName: zone_name,
          ProductName: batch.attributes['crop_variety'],
          Label: barcode,
          PackagedDate: package_date
        }]
      end

      def product_package_payload
        harvest = lookup_harvest(batch_tag)

        [{
          HarvestId: harvest['id'],
          Label: batch_tag,
          RoomName: zone_name,
          ProductName: batch.attributes['crop_variety'],
          Weight: batch.attributes['quantity']&.to_i,
          UnitOfMeasureName: unit_of_weight,
          IsProductionBatch: false,
          ProductionBatchNumber: nil,
          ProductRequiresRemediation: false,
          RemediationMethodId: nil,
          RemediationDate: nil,
          RemediationSteps: nil,
          PackagedDate: package_date
        }]
      end

      def create_product_package
        payload = product_package_payload
        call_ncs(:harvest, :create_package, payload)
      end

      def testing?
        batch.arbitrary_id.match?(/test/i)
      end

      def plant_package
        item_type == 'Plant'
      end

      def barcode
        batch.relationships.dig('barcodes', 'data', 0, 'id')
      end

      def item_type
        @item_type ||= begin
          case resource_units&.first&.name
          when /Plant/
            'Plant'
          else
            'Flower'
          end
        end
      end

      def zone_name
        get_zone(batch.relationships.dig('zone', 'data', 'id')).name
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

      def unit_of_weight
        validate_resource_units!

        resource_units.first.unit
      end

      def validate_resource_units!
        raise InvalidAttributes, 'The package contains resources of multiple types or units. Expected all resources in the package to be the same' \
          unless resource_units.uniq(&:unit).count == 1
      end
    end
  end
end

module MetrcService
  module Plant
    class Start < Base
      ORIGIN_PACKAGES = ['Source Package Id (Metrc)'].freeze
      PLANT_MOTHER_NAME = /mother id/i.freeze
      CLOSED_LOOP_STATES = %i[ma ca].freeze

      def call
        if origin_package
          transaction.update(type: :start_batch_from_package)
          create_plantings_from_package
        elsif source_plant
          transaction.update(type: :start_batch_from_source_plant)
          create_plant_batch_from_mother
        else
          create_plant_batch
        end

        success!
      end

      private

      def transaction
        @transaction ||= get_transaction(:start_batch)
      end

      def create_plant_batch
        call_metrc(:create_plant_batches, build_start_payload)
      end

      def build_start_payload
        seeding_unit = batch.zone&.attributes&.dig('seeding_unit', 'name')&.downcase
        type = /seed/.match?(seeding_unit) ? 'Seed' : 'Clone'

        [{
          Name: batch_tag,
          Type: type,
          Count: quantity,
          Strain: batch.crop_variety,
          Location: location_name,
          PatientLicenseNumber: nil,
          ActualDate: batch.seeded_at
        }]
      end

      def create_plantings_from_package
        call_metrc(:create_plantings_package, create_plantings_from_package_payload)

        # Some clients start their plantings with teens
        # and at a specific growth phase (like flowering).
        # This sends it to the correct stage on Metrc if item tracking method is different from `none`.
        MetrcService::Plant::Move.call(@ctx, @integration) if item_tracking_method != 'none'
      end

      def create_plantings_from_package_payload
        label = package_label(origin_package&.id)

        raise InvalidOperation, "Failed: No package label was found for #{origin_package&.name}" unless label && label&.value

        [{
          PackageLabel: label.value,
          PackageAdjustmentAmount: 0,
          PackageAdjustmentUnitOfMeasureName: 'Each',
          PlantBatchName: batch_tag,
          PlantBatchType: 'Clone',
          PlantCount: quantity,
          LocationName: location_name,
          StrainName: batch.crop_variety,
          PatientLicenseNumber: nil,
          PlantedDate: batch.seeded_at,
          UnpackagedDate: batch.seeded_at
        }]
      end

      def create_plant_batch_from_mother
        call_metrc(:create_plant_batch_from_mother, create_plant_batch_from_mother_payload)
      end

      def create_plant_batch_from_mother_payload
        source_plant_tag = package_label(source_plant&.id)

        raise InvalidOperation, "Failed: No source plant was found for #{source_plant&.name}" unless source_plant_tag&.value

        [{
          PlantLabel: source_plant_tag.value, # <--------- Mother plant that is being used to create the plant batch
          PlantBatchName: batch_tag, # < ------------ Name of the plant batch that is being created
          PlantBatchType: 'Clone',
          PlantCount: quantity,
          LocationName: location_name,
          StrainName: batch.crop_variety,
          PatientLicenseNumber: nil,
          ActualDate: batch.seeded_at
        }]
      end

      def custom_data
        batch.included&.dig(:custom_data)
      end

      def custom_fields
        batch.included&.dig(:custom_fields)
      end

      def quantity
        @attributes.dig('options', 'quantity')&.to_i
      end

      def origin_package
        @origin_package ||= custom_fields&.detect { |obj| ORIGIN_PACKAGES.include?(obj&.name) }
      end

      def source_plant
        @source_plant ||= custom_fields&.detect { |obj| PLANT_MOTHER_NAME.match?(obj&.name) }
      end

      def package_label(target_id)
        return unless target_id

        custom_data&.detect { |obj| obj&.relationships&.dig('custom_field', 'data', 'id')&.to_i == target_id&.to_i }
      end
    end
  end
end
